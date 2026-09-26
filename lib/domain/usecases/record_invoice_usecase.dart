import '../entities/shop_entities.dart';
import '../repositories/shop_repository.dart';

/// Persists a sale/purchase invoice and applies its stock and balance
/// effects.
///
/// This is the business rule that used to live inside the SQL transaction:
/// a sale takes stock away and adds to what the customer owes; a purchase
/// adds stock and adds to what we owe the supplier. Computing that here
/// (instead of in the repository) is what lets the repository stay dumb
/// persistence - it never has to know what a "sale" means.
class RecordInvoiceUseCase {
  const RecordInvoiceUseCase(this._repository);
  final ShopRepository _repository;

  Future<void> call(Invoice invoice, List<InvoiceItem> items) async {
    final sign = invoice.kind == 'sale' ? -1.0 : 1.0;
    final productQuantityDeltas = <String, double>{};
    for (final item in items) {
      final productId = item.productId;
      if (productId == null) continue;
      productQuantityDeltas[productId] =
          (productQuantityDeltas[productId] ?? 0) + sign * item.qty;
    }

    double? partyBalanceDelta;
    if (invoice.partyId != null) {
      partyBalanceDelta =
          invoice.kind == 'sale' ? invoice.remaining : -invoice.remaining;
    }

    await _repository.recordInvoice(
      invoice,
      items,
      productQuantityDeltas: productQuantityDeltas,
      partyBalanceDelta: partyBalanceDelta,
    );
  }
}
