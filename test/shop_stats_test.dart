import 'package:flutter_test/flutter_test.dart';
import 'package:super_market_pro_max/core/logic/shop_stats.dart';
import 'package:super_market_pro_max/core/models/shop_models.dart';

Invoice _inv(String id, String kind, double total, double paid, int date) {
  return Invoice(id: id, kind: kind, total: total, paid: paid, date: date);
}

InvoiceItem _item(String invId, String name, double qty, double buy, double sell) {
  return InvoiceItem(
    id: '$invId-$name',
    invoiceId: invId,
    productName: name,
    qty: qty,
    buyPrice: buy,
    sellPrice: sell,
  );
}

void main() {
  const day = 1000;
  const next = 2000;

  test('computeStats totals sales, purchases, profit and unpaid', () {
    final stats = computeStats(
      invoices: [
        _inv('s1', 'sale', 500, 400, 1200),
        _inv('s2', 'sale', 200, 200, 1300),
        _inv('p1', 'purchase', 1000, 600, 1400),
        _inv('old', 'sale', 9999, 0, 500), // out of range
      ],
      saleItems: [
        _item('s1', 'Sugar', 10, 20, 30), // profit 100
        _item('s2', 'Rice', 5, 30, 40), // profit 50
        _item('old', 'Old', 99, 1, 100), // out of range
      ],
      fromMillis: day,
      toMillis: next,
    );

    expect(stats.salesTotal, 700);
    expect(stats.purchasesTotal, 1000);
    expect(stats.profit, 150);
    expect(stats.unpaidSales, 100);
    expect(stats.unpaidPurchases, 400);
    expect(stats.salesCount, 2);
    expect(stats.purchasesCount, 1);
  });

  test('topSelling ranks by quantity with limit', () {
    final top = topSelling([
      _item('a', 'Sugar', 10, 1, 2),
      _item('b', 'Rice', 25, 1, 2),
      _item('c', 'Sugar', 5, 1, 2),
      _item('d', 'Oil', 7, 1, 2),
    ], limit: 2);

    expect(top.length, 2);
    expect(top[0].key, 'Rice');
    expect(top[0].value, 25);
    expect(top[1].key, 'Sugar');
    expect(top[1].value, 15);
  });

  test('invoice remaining is total minus paid', () {
    const inv = Invoice(id: 'x', kind: 'sale', total: 300, paid: 120, date: 0);
    expect(inv.remaining, 180);
  });

  test('product profit per unit', () {
    const p = Product(
      id: 'p',
      name: 'Tea',
      buyPrice: 40,
      sellPrice: 55,
      createdAt: 0,
    );
    expect(p.profitPerUnit, 15);
  });

  test('unit cost is auto-computed from carton price and factor', () {
    const p = Product(
      id: 'p',
      name: 'Sugar',
      buyPrice: 240,
      sellPrice: 25,
      createdAt: 0,
      purchaseUnit: 'كرتون',
      unitFactor: 12,
      unitName: 'قطعة',
    );
    expect(p.unitCost, 20);
  });

  test('profitByProduct ranks products by profit', () {
    final list = profitByProduct([
      _item('a', 'Sugar', 10, 20, 30), // 100
      _item('b', 'Rice', 5, 30, 40), // 50
      _item('c', 'Sugar', 5, 20, 30), // +50 => Sugar 150 total, qty 15
    ]);
    expect(list.length, 2);
    expect(list[0].name, 'Sugar');
    expect(list[0].profit, 150);
    expect(list[0].qty, 15);
    expect(list[1].name, 'Rice');
  });

  test('product copyWith keeps id and dates', () {
    const p = Product(id: 'p', name: 'Tea', buyPrice: 10, sellPrice: 15, createdAt: 7);
    final c = p.copyWith(sellPrice: 20);
    expect(c.id, 'p');
    expect(c.createdAt, 7);
    expect(c.sellPrice, 20);
    expect(c.buyPrice, 10);
  });
}
