/// Small persisted app state that isn't shop data - which account last used
/// this device, and when it last synced. Kept behind its own interface (not
/// just SharedPreferences calls sprinkled through the sync logic) so the
/// account-switch decision in [HandleSignInUseCase] stays testable.
abstract class PreferencesGateway {
  Future<String?> getLastUserId();
  Future<void> setLastUserId(String userId);
  Future<DateTime?> getLastSyncedAt();
  Future<void> setLastSyncedAt(DateTime time);
}
