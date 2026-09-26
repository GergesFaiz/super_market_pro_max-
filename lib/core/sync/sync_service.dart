import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../data/shop_repository.dart';

enum SyncStatus { idle, syncing, error, signedOut }

/// Backs up the local database to Supabase whenever the device is online and
/// signed in. Every row is scoped to the signed-in user (`user_id`), so each
/// Google account's data is fully isolated - selling the app/device to
/// another shop and signing in with a different account never mixes data.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _kLastUserId = 'sync_last_user_id';

  ShopRepository? _repo;
  bool _dirty = false;
  bool _pushing = false;
  Timer? _debounce;
  DateTime? lastSyncedAt;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus _status = SyncStatus.signedOut;
  SyncStatus get status => _status;

  sb.SupabaseClient get _client => sb.Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  Future<void> init(ShopRepository repo) async {
    _repo = repo;
    // Sign-in is handled explicitly via [onSignedIn] (it needs to decide
    // whether to wipe local data first), so only react here to sign-out.
    _client.auth.onAuthStateChange.listen((state) {
      if (state.session == null) _setStatus(SyncStatus.signedOut);
    });
    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) syncNow();
    });
    unawaited(syncNow());
  }

  /// Call after any local write; pushes soon if online and signed in.
  void notifyChanged() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  /// True when the account signing in now is different from the one last
  /// used to sync on this device - i.e. the device likely changed hands.
  Future<bool> isDifferentAccountThanBefore() async {
    final userId = _userId;
    if (userId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final lastUserId = prefs.getString(_kLastUserId);
    return lastUserId != null && lastUserId.isNotEmpty && lastUserId != userId;
  }

  /// Call right after sign-in. If [wipeLocalFirst] is true, the local
  /// database is cleared before pulling this account's cloud data, so a new
  /// owner never sees a previous shop's data mixed with theirs.
  Future<void> onSignedIn({bool wipeLocalFirst = false}) async {
    final userId = _userId;
    final repo = _repo;
    if (userId == null || repo == null) return;
    if (wipeLocalFirst) {
      await repo.wipeLocal();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastUserId, userId);
    await syncNow();
  }

  /// Pushes local changes to Supabase, and pulls any newer remote rows back
  /// (e.g. after signing in on a new device with the same account).
  Future<void> syncNow() async {
    final repo = _repo;
    final userId = _userId;
    if (repo == null) return;
    if (userId == null) {
      _setStatus(SyncStatus.signedOut);
      return;
    }
    if (_pushing) return;
    if (!await _isOnline()) return;
    _pushing = true;
    _setStatus(SyncStatus.syncing);
    try {
      for (final table in kSyncTables) {
        final localRows = await repo.tableRows(table);
        if (localRows.isNotEmpty) {
          final rowsWithOwner =
              localRows.map((r) => {...r, 'user_id': userId}).toList();
          await _client.from(table).upsert(rowsWithOwner);
        }
        final remoteRows =
            await _client.from(table).select().eq('user_id', userId);
        await repo.mergeRows(table, _stripOwner(remoteRows));
      }
      _dirty = false;
      lastSyncedAt = DateTime.now();
      _setStatus(SyncStatus.idle);
    } catch (_) {
      _setStatus(SyncStatus.error);
    } finally {
      _pushing = false;
      if (_dirty) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 5), syncNow);
      }
    }
  }

  List<Map<String, Object?>> _stripOwner(List<dynamic> rows) {
    return rows
        .map((r) => Map<String, Object?>.from(r as Map)..remove('user_id'))
        .toList();
  }

  void _setStatus(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }
}
