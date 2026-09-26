import '../entities/shop_snapshot.dart';

/// Whatever cloud backend backs up the shop's data (Supabase today, maybe
/// something else later) is reached only through this interface. The sync
/// use case talks to a [SyncGateway], never to an SDK.
abstract class SyncGateway {
  Future<void> push(ShopSnapshot snapshot, String ownerId);
  Future<ShopSnapshot> pull(String ownerId);
}
