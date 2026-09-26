import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../domain/repositories/auth_gateway.dart';
import '../../domain/usecases/handle_sign_in_usecase.dart';
import '../../domain/usecases/sync_data_usecase.dart';

enum SyncStatus { idle, syncing, error, signedOut }

/// The application-layer controller the UI talks to for everything
/// auth/sync related. It owns no business rules itself - those live in
/// [SyncDataUseCase] and [HandleSignInUseCase] - it only wires connectivity
/// and app lifecycle events to them and exposes a status stream for screens
/// to display.
///
/// Kept as a singleton (configured once at startup via [configure]) since
/// there's exactly one of these per running app and several unrelated
/// screens need to reach it without a dependency-injection framework.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  late AuthGateway _authGateway;
  late SyncDataUseCase _syncDataUseCase;
  late HandleSignInUseCase _handleSignInUseCase;

  bool _dirty = false;
  bool _pushing = false;
  Timer? _debounce;
  DateTime? lastSyncedAt;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus _status = SyncStatus.signedOut;
  SyncStatus get status => _status;

  /// The identity gateway, exposed so screens (login, backup) can show the
  /// signed-in account or trigger sign-in/out without importing an auth SDK
  /// directly.
  AuthGateway get auth => _authGateway;

  void configure({
    required AuthGateway authGateway,
    required SyncDataUseCase syncDataUseCase,
    required HandleSignInUseCase handleSignInUseCase,
  }) {
    _authGateway = authGateway;
    _syncDataUseCase = syncDataUseCase;
    _handleSignInUseCase = handleSignInUseCase;
  }

  Future<void> init() async {
    _authGateway.userIdChanges.listen((userId) {
      if (userId == null) _setStatus(SyncStatus.signedOut);
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
    final userId = _authGateway.currentUserId;
    if (userId == null) return false;
    return _handleSignInUseCase.isDifferentAccountThanBefore(userId);
  }

  /// Call right after sign-in, once the UI has decided whether to wipe local
  /// data first (see [isDifferentAccountThanBefore]).
  Future<void> onSignedIn({bool wipeLocalFirst = false}) async {
    final userId = _authGateway.currentUserId;
    if (userId == null) return;
    await _handleSignInUseCase(userId, wipeLocalFirst: wipeLocalFirst);
    await syncNow();
  }

  Future<void> syncNow() async {
    final userId = _authGateway.currentUserId;
    if (userId == null) {
      _setStatus(SyncStatus.signedOut);
      return;
    }
    if (_pushing) return;
    if (!await _isOnline()) return;
    _pushing = true;
    _setStatus(SyncStatus.syncing);
    try {
      await _syncDataUseCase(userId);
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

  void _setStatus(SyncStatus s) {
    _status = s;
    _statusController.add(s);
  }
}
