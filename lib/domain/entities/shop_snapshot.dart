import 'shop_entities.dart';

/// A full copy of the shop's local data, used to back up to the cloud and
/// restore from it. Keeping this as one value object (rather than passing six
/// separate lists around) is what lets the sync use case and gateway stay
/// generic about "all of the user's data" without needing to know the SQL or
/// HTTP specifics of any one table.
class ShopSnapshot {
  final List<Category> categories;
  final List<Product> products;
  final List<Party> parties;
  final List<Invoice> invoices;
  final List<InvoiceItem> invoiceItems;
  final List<Expense> expenses;

  const ShopSnapshot({
    this.categories = const [],
    this.products = const [],
    this.parties = const [],
    this.invoices = const [],
    this.invoiceItems = const [],
    this.expenses = const [],
  });
}
