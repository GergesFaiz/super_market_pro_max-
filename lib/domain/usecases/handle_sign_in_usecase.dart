import '../repositories/preferences_gateway.dart';
import '../repositories/shop_repository.dart';

/// Decides what happens to the local database when an account signs in on
/// this device.
///
/// If a different account was last used here, the previous shop's data must
/// never silently mix with the new one's - the UI asks the user to choose,
/// and this use case carries out that choice.
class HandleSignInUseCase {
  const HandleSignInUseCase(this._repository, this._preferences);
  final ShopRepository _repository;
  final PreferencesGateway _preferences;

  Future<bool> isDifferentAccountThanBefore(String userId) async {
    final lastUserId = await _preferences.getLastUserId();
    return lastUserId != null && lastUserId.isNotEmpty && lastUserId != userId;
  }

  Future<void> call(String userId, {required bool wipeLocalFirst}) async {
    if (wipeLocalFirst) {
      await _repository.wipeAll();
    }
    await _preferences.setLastUserId(userId);
  }
}
