import '../entities/shop_entities.dart';
import '../entities/shop_snapshot.dart';

/// The boundary between the app's business logic and however data actually
/// gets persisted. Nothing in `domain/` or the UI is allowed to know whether
/// this is backed by SQLite, a remote API, or an in-memory map - only the
/// concrete implementation in `data/` knows that.
abstract class ShopRepository {
  // ── Categories ──
  Future<List<Category>> getCategories();
  Future<void> addCategory(Category category);
  Future<void> deleteCategory(String id);

  // ── Products ──
  Future<List<Product>> getProducts({String query = ''});
  Future<void> upsertProduct(Product product);
  Future<void> deleteProduct(String id);
  Future<List<Product>> lowStock(double threshold);

  // ── Parties ──
  Future<List<Party>> getParties(String kind);
  Future<void> upsertParty(Party party);
  Future<void> deleteParty(String id);

  // ── Invoices ──
  /// Persists [invoice] and [items], applying [productQuantityDeltas] and
  /// [partyBalanceDelta] atomically alongside them.
  ///
  /// This method does not decide *what* those deltas should be - a sale vs.
  /// a purchase moves stock and balances in opposite directions, and that
  /// decision is a business rule that belongs to a use case, not to
  /// persistence code. The repository's job is only to save what it's told.
  Future<void> recordInvoice(
    Invoice invoice,
    List<InvoiceItem> items, {
    required Map<String, double> productQuantityDeltas,
    double? partyBalanceDelta,
  });
  Future<List<Invoice>> getInvoices(String kind, {int limit = 100});
  Future<List<Invoice>> getInvoicesInRange(int from, int to);
  Future<List<InvoiceItem>> getItems(String invoiceId);
  Future<List<InvoiceItem>> getSaleItemsInRange(int from, int to);

  // ── Expenses ──
  Future<List<Expense>> getExpensesInRange(int from, int to);
  Future<void> addExpense(Expense expense);
  Future<void> deleteExpense(String id);

  // ── Backup / sync ──
  Future<String> exportJson();
  Future<void> importJson(String json);
  Future<ShopSnapshot> getSnapshot();
  Future<void> mergeSnapshot(ShopSnapshot snapshot);
  Future<void> wipeAll();
}
