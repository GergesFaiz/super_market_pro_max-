class Category {
  final String id;
  final String name;
  const Category({required this.id, required this.name});

  Map<String, Object?> toMap() => {'id': id, 'name': name};

  factory Category.fromMap(Map<String, Object?> m) =>
      Category(id: m['id']! as String, name: m['name']! as String);
}

class Product {
  final String id;
  final String name;
  final String barcode;
  final String? categoryId;
  final double buyPrice;
  final double sellPrice;
  final double quantity;
  final int createdAt;

  /// Multi-unit support (e.g. buy by carton, sell by piece):
  /// [purchaseUnit] like 'كرتون', [unitFactor] pieces per purchase unit,
  /// [unitName] like 'قطعة'. When [unitFactor] > 1 the effective
  /// cost per piece is buyPrice / factor.
  final String purchaseUnit;
  final double unitFactor;
  final String unitName;

  const Product({
    required this.id,
    required this.name,
    this.barcode = '',
    this.categoryId,
    required this.buyPrice,
    required this.sellPrice,
    this.quantity = 0,
    required this.createdAt,
    this.purchaseUnit = '',
    this.unitFactor = 1,
    this.unitName = '',
  });

  double get profitPerUnit => sellPrice - buyPrice;

  /// Cost of one selling unit (auto: purchase price / factor).
  double get unitCost => unitFactor > 0 ? buyPrice / unitFactor : buyPrice;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'category_id': categoryId,
        'buy_price': buyPrice,
        'sell_price': sellPrice,
        'quantity': quantity,
        'created_at': createdAt,
        'purchase_unit': purchaseUnit,
        'unit_factor': unitFactor,
        'unit_name': unitName,
      };

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id']! as String,
        name: m['name']! as String,
        barcode: (m['barcode'] as String?) ?? '',
        categoryId: m['category_id'] as String?,
        buyPrice: (m['buy_price'] as num).toDouble(),
        sellPrice: (m['sell_price'] as num).toDouble(),
        quantity: (m['quantity'] as num).toDouble(),
        createdAt: m['created_at']! as int,
        purchaseUnit: (m['purchase_unit'] as String?) ?? '',
        unitFactor: ((m['unit_factor'] as num?) ?? 1).toDouble(),
        unitName: (m['unit_name'] as String?) ?? '',
      );
}

class Party {
  final String id;
  final String name;
  final String phone;
  final String kind; // customer | supplier
  final double balance; // >0 means they owe us, <0 we owe them

  const Party({
    required this.id,
    required this.name,
    this.phone = '',
    required this.kind,
    this.balance = 0,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'kind': kind,
        'balance': balance,
      };

  factory Party.fromMap(Map<String, Object?> m) => Party(
        id: m['id']! as String,
        name: m['name']! as String,
        phone: (m['phone'] as String?) ?? '',
        kind: m['kind']! as String,
        balance: (m['balance'] as num).toDouble(),
      );
}

class Invoice {
  final String id;
  final String kind; // sale | purchase
  final String? partyId;
  final double total;
  final double paid;
  final double discount;
  final int date;
  final String notes;

  const Invoice({
    required this.id,
    required this.kind,
    this.partyId,
    required this.total,
    required this.paid,
    this.discount = 0,
    required this.date,
    this.notes = '',
  });

  double get remaining => total - paid;

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind,
        'party_id': partyId,
        'total': total,
        'paid': paid,
        'discount': discount,
        'date': date,
        'notes': notes,
      };

  factory Invoice.fromMap(Map<String, Object?> m) => Invoice(
        id: m['id']! as String,
        kind: m['kind']! as String,
        partyId: m['party_id'] as String?,
        total: (m['total'] as num).toDouble(),
        paid: (m['paid'] as num).toDouble(),
        discount: ((m['discount'] as num?) ?? 0).toDouble(),
        date: m['date']! as int,
        notes: (m['notes'] as String?) ?? '',
      );
}

class InvoiceItem {
  final String id;
  final String invoiceId;
  final String? productId;
  final String productName;
  final double qty;
  final double buyPrice;
  final double sellPrice;

  const InvoiceItem({
    required this.id,
    required this.invoiceId,
    this.productId,
    required this.productName,
    required this.qty,
    required this.buyPrice,
    required this.sellPrice,
  });

  /// Profit for a sale line; for purchases this is 0 by definition.
  double get lineProfit => (sellPrice - buyPrice) * qty;

  Map<String, Object?> toMap() => {
        'id': id,
        'invoice_id': invoiceId,
        'product_id': productId,
        'product_name': productName,
        'qty': qty,
        'buy_price': buyPrice,
        'sell_price': sellPrice,
      };

  factory InvoiceItem.fromMap(Map<String, Object?> m) => InvoiceItem(
        id: m['id']! as String,
        invoiceId: m['invoice_id']! as String,
        productId: m['product_id'] as String?,
        productName: m['product_name']! as String,
        qty: (m['qty'] as num).toDouble(),
        buyPrice: (m['buy_price'] as num).toDouble(),
        sellPrice: (m['sell_price'] as num).toDouble(),
      );
}
