import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../data/shop_repository.dart';
import 'supabase_config.dart';

enum SyncStatus { idle, syncing, error }

/// Backs up the local database to Supabase whenever the device is online,
/// so data survives even if the phone is lost, reset, or the app reinstalled
/// (as long as the same device id is used to restore).
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _kDeviceId = 'sync_device_id';
  static const _kLastSyncedAt = 'sync_last_synced_at';

  ShopRepository? _repo;
  String _deviceId = '';
  bool _dirty = false;
  bool _pushing = false;
  Timer? _debounce;
  DateTime? lastSyncedAt;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  String get deviceId => _deviceId;

  Future<void> init(ShopRepository repo) async {
    _repo = repo;
    await sb.Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_kDeviceId) ?? '';
    if (_deviceId.isEmpty) {
      _deviceId = const Uuid().v4();
      await prefs.setString(_kDeviceId, _deviceId);
    }
    final savedSync = prefs.getInt(_kLastSyncedAt);
    if (savedSync != null) {
      lastSyncedAt = DateTime.fromMillisecondsSinceEpoch(savedSync);
    }

    Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) syncNow();
    });
    // Try once at startup too.
    unawaited(syncNow());
  }

  /// Call after any local write; pushes soon if online.
  void notifyChanged() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  /// Pushes local changes to Supabase, and pulls any newer remote rows back
  /// (e.g. after restoring the app on the same device id).
  Future<void> syncNow() async {
    final repo = _repo;
    if (repo == null || _pushing) return;
    if (!await _isOnline()) return;
    _pushing = true;
    _setStatus(SyncStatus.syncing);
    try {
      final client = sb.Supabase.instance.client;
      for (final table in kSyncTables) {
        final localRows = await repo.tableRows(table);
        final rowsWithDevice = localRows
            .map((r) => {...r, 'device_id': _deviceId})
            .toList();
        if (rowsWithDevice.isNotEmpty) {
          await client.from(table).upsert(rowsWithDevice);
        }
        final remoteRows = await client
            .from(table)
            .select()
            .eq('device_id', _deviceId);
        await repo.mergeRows(table, _stripDeviceId(remoteRows));
      }
      _dirty = false;
      lastSyncedAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLastSyncedAt, lastSyncedAt!.millisecondsSinceEpoch);
      _setStatus(SyncStatus.idle);
    } catch (_) {
      _setStatus(SyncStatus.error);
    } finally {
      _pushing = false;
      if (_dirty) {
        // A write happened while syncing; try again shortly.
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 5), syncNow);
      }
    }
  }

  /// Pulls all data stored under [otherDeviceId] into the local database.
  /// Used to restore a backup onto a new/reset device.
  Future<void> restoreFromDeviceId(String otherDeviceId) async {
    final repo = _repo;
    if (repo == null) return;
    final client = sb.Supabase.instance.client;
    for (final table in kSyncTables) {
      final remoteRows = await client
          .from(table)
          .select()
          .eq('device_id', otherDeviceId);
      await repo.mergeRows(table, _stripDeviceId(remoteRows));
    }
  }

  List<Map<String, Object?>> _stripDeviceId(List<dynamic> rows) {
    return rows
        .map((r) => Map<String, Object?>.from(r as Map)..remove('device_id'))
        .toList();
  }

  void _setStatus(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }
}
