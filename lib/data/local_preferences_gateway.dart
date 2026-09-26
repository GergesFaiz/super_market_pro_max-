import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/preferences_gateway.dart';

/// [PreferencesGateway] backed by [SharedPreferences].
class LocalPreferencesGateway implements PreferencesGateway {
  static const _kLastUserId = 'sync_last_user_id';
  static const _kLastSyncedAt = 'sync_last_synced_at';

  @override
  Future<String?> getLastUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastUserId);
  }

  @override
  Future<void> setLastUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastUserId, userId);
  }

  @override
  Future<DateTime?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_kLastSyncedAt);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<void> setLastSyncedAt(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastSyncedAt, time.millisecondsSinceEpoch);
  }
}
