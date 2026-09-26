import '../entities/shop_entities.dart';

/// Pure profit/report calculations (unit-testable, no DB).
class ShopStats {
  final double salesTotal;
  final double purchasesTotal;
  final double profit;
  final double unpaidSales;
  final double unpaidPurchases;
  final int salesCount;
  final int purchasesCount;

  const ShopStats({
    required this.salesTotal,
    required this.purchasesTotal,
    required this.profit,
    required this.unpaidSales,
    required this.unpaidPurchases,
    required this.salesCount,
    required this.purchasesCount,
  });

  static const empty = ShopStats(
    salesTotal: 0,
    purchasesTotal: 0,
    profit: 0,
    unpaidSales: 0,
    unpaidPurchases: 0,
    salesCount: 0,
    purchasesCount: 0,
  );
}

ShopStats computeStats({
  required List<Invoice> invoices,
  required List<InvoiceItem> saleItems,
  required int fromMillis,
  required int toMillis,
}) {
  final inRange =
      invoices.where((i) => i.date >= fromMillis && i.date < toMillis).toList();
  final ids = inRange.map((e) => e.id).toSet();

  double sales = 0, purchases = 0, unpaidS = 0, unpaidP = 0;
  int sCount = 0, pCount = 0;
  for (final inv in inRange) {
    if (inv.kind == 'sale') {
      sales += inv.total;
      unpaidS += inv.remaining;
      sCount++;
    } else {
      purchases += inv.total;
      unpaidP += inv.remaining;
      pCount++;
    }
  }
  double profit = 0;
  for (final item in saleItems) {
    if (ids.contains(item.invoiceId)) profit += item.lineProfit;
  }
  return ShopStats(
    salesTotal: sales,
    purchasesTotal: purchases,
    profit: profit,
    unpaidSales: unpaidS,
    unpaidPurchases: unpaidP,
    salesCount: sCount,
    purchasesCount: pCount,
  );
}

/// Top selling products by quantity in the given sale lines.
List<MapEntry<String, double>> topSelling(List<InvoiceItem> saleItems, {int limit = 5}) {
  final map = <String, double>{};
  for (final it in saleItems) {
    map.update(it.productName, (v) => v + it.qty, ifAbsent: () => it.qty);
  }
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(limit).toList();
}

/// Profit aggregated per product (most profitable products).
class ProductProfit {
  final String name;
  final double qty;
  final double revenue;
  final double profit;
  const ProductProfit({
    required this.name,
    required this.qty,
    required this.revenue,
    required this.profit,
  });
}

List<ProductProfit> profitByProduct(List<InvoiceItem> saleItems, {int limit = 10}) {
  final map = <String, ProductProfit>{};
  for (final it in saleItems) {
    final prev = map[it.productName];
    map[it.productName] = ProductProfit(
      name: it.productName,
      qty: (prev?.qty ?? 0) + it.qty,
      revenue: (prev?.revenue ?? 0) + it.sellPrice * it.qty,
      profit: (prev?.profit ?? 0) + it.lineProfit,
    );
  }
  final list = map.values.toList()
    ..sort((a, b) => b.profit.compareTo(a.profit));
  return list.take(limit).toList();
}
