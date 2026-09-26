import '../repositories/shop_repository.dart';
import '../repositories/sync_gateway.dart';

/// Backs up the signed-in user's local data to the cloud and pulls back
/// anything newer, so the data survives even if the device is lost or reset.
class SyncDataUseCase {
  const SyncDataUseCase(this._repository, this._gateway);
  final ShopRepository _repository;
  final SyncGateway _gateway;

  Future<void> call(String ownerId) async {
    final localSnapshot = await _repository.getSnapshot();
    await _gateway.push(localSnapshot, ownerId);
    final remoteSnapshot = await _gateway.pull(ownerId);
    await _repository.mergeSnapshot(remoteSnapshot);
  }
}
