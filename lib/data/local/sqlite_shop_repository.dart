import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/shop_entities.dart';
import '../../domain/entities/shop_snapshot.dart';
import '../../domain/repositories/shop_repository.dart';
import 'app_database.dart';

const kSyncTables = [
  'categories',
  'products',
  'parties',
  'invoices',
  'invoice_items',
  'expenses',
];

/// SQLite-backed [ShopRepository] - the only place in the app that knows
/// this data lives in a local sqflite database.
class SqliteShopRepository implements ShopRepository {
  SqliteShopRepository({AppDatabase? database, this.onWrite})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  /// Called after any mutating operation, so the sync controller can react
  /// (e.g. push the change to the cloud when online).
  final void Function()? onWrite;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  // ── Categories ──
  @override
  Future<List<Category>> getCategories() async {
    final db = await _database.db;
    final rows = await db.query('categories', orderBy: 'name');
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<void> addCategory(Category category) async {
    final db = await _database.db;
    await db.insert('categories', category.copyWithUpdatedAt(_now).toMap());
    onWrite?.call();
  }

  @override
  Future<void> deleteCategory(String id) async {
    final db = await _database.db;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    onWrite?.call();
  }

  // ── Products ──
  @override
  Future<List<Product>> getProducts({String query = ''}) async {
    final db = await _database.db;
    if (query.trim().isEmpty) {
      final rows = await db.query('products', orderBy: 'name');
      return rows.map(Product.fromMap).toList();
    }
    final rows = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name',
    );
    return rows.map(Product.fromMap).toList();
  }

  @override
  Future<void> upsertProduct(Product product) async {
    final db = await _database.db;
    await db.insert(
      'products',
      product.copyWithUpdatedAt(_now).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    onWrite?.call();
  }

  @override
  Future<void> deleteProduct(String id) async {
    final db = await _database.db;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    onWrite?.call();
  }

  @override
  Future<List<Product>> lowStock(double threshold) async {
    final db = await _database.db;
    final rows = await db.query('products',
        where: 'quantity <= ?', whereArgs: [threshold], orderBy: 'quantity');
    return rows.map(Product.fromMap).toList();
  }

  // ── Parties ──
  @override
  Future<List<Party>> getParties(String kind) async {
    final db = await _database.db;
    final rows = await db.query('parties',
        where: 'kind = ?', whereArgs: [kind], orderBy: 'name');
    return rows.map(Party.fromMap).toList();
  }

  @override
  Future<void> upsertParty(Party party) async {
    final db = await _database.db;
    await db.insert('parties', party.copyWithUpdatedAt(_now).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    onWrite?.call();
  }

  @override
  Future<void> deleteParty(String id) async {
    final db = await _database.db;
    await db.delete('parties', where: 'id = ?', whereArgs: [id]);
    onWrite?.call();
  }

  // ── Invoices ──
  @override
  Future<void> recordInvoice(
    Invoice invoice,
    List<InvoiceItem> items, {
    required Map<String, double> productQuantityDeltas,
    double? partyBalanceDelta,
  }) async {
    final db = await _database.db;
    final now = _now;
    await db.transaction((txn) async {
      await txn.insert('invoices', invoice.copyWithUpdatedAt(now).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('invoice_items',
          where: 'invoice_id = ?', whereArgs: [invoice.id]);
      for (final it in items) {
        await txn.insert('invoice_items', it.copyWithUpdatedAt(now).toMap());
      }
      for (final entry in productQuantityDeltas.entries) {
        await txn.rawUpdate(
          'UPDATE products SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
          [entry.value, now, entry.key],
        );
      }
      if (invoice.partyId != null && partyBalanceDelta != null) {
        await txn.rawUpdate(
          'UPDATE parties SET balance = balance + ?, updated_at = ? WHERE id = ?',
          [partyBalanceDelta, now, invoice.partyId],
        );
      }
    });
    onWrite?.call();
  }

  @override
  Future<List<Invoice>> getInvoices(String kind, {int limit = 100}) async {
    final db = await _database.db;
    final rows = await db.query('invoices',
        where: 'kind = ?',
        whereArgs: [kind],
        orderBy: 'date DESC',
        limit: limit);
    return rows.map(Invoice.fromMap).toList();
  }

  @override
  Future<List<Invoice>> getInvoicesInRange(int from, int to) async {
    final db = await _database.db;
    final rows = await db.query('invoices',
        where: 'date >= ? AND date < ?',
        whereArgs: [from, to],
        orderBy: 'date DESC');
    return rows.map(Invoice.fromMap).toList();
  }

  @override
  Future<List<InvoiceItem>> getItems(String invoiceId) async {
    final db = await _database.db;
    final rows = await db.query('invoice_items',
        where: 'invoice_id = ?', whereArgs: [invoiceId]);
    return rows.map(InvoiceItem.fromMap).toList();
  }

  @override
  Future<List<InvoiceItem>> getSaleItemsInRange(int from, int to) async {
    final db = await _database.db;
    final rows = await db.rawQuery('''
      SELECT ii.* FROM invoice_items ii
      JOIN invoices i ON i.id = ii.invoice_id
      WHERE i.kind = 'sale' AND i.date >= ? AND i.date < ?
    ''', [from, to]);
    return rows.map(InvoiceItem.fromMap).toList();
  }

  // ── Expenses ──
  @override
  Future<List<Expense>> getExpensesInRange(int from, int to) async {
    final db = await _database.db;
    final rows = await db.query('expenses',
        where: 'date >= ? AND date < ?',
        whereArgs: [from, to],
        orderBy: 'date DESC');
    return rows.map(Expense.fromMap).toList();
  }

  @override
  Future<void> addExpense(Expense expense) async {
    final db = await _database.db;
    await db.insert('expenses', expense.copyWithUpdatedAt(_now).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    onWrite?.call();
  }

  @override
  Future<void> deleteExpense(String id) async {
    final db = await _database.db;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    onWrite?.call();
  }

  // ── Backup / sync ──
  @override
  Future<String> exportJson() async {
    final db = await _database.db;
    final data = <String, Object>{};
    for (final t in kSyncTables) {
      data[t] = await db.query(t);
    }
    return jsonEncode(data);
  }

  @override
  Future<void> importJson(String json) async {
    final db = await _database.db;
    final data = jsonDecode(json) as Map<String, dynamic>;
    await db.transaction((txn) async {
      for (final t in kSyncTables) {
        await txn.delete(t);
        final rows = (data[t] as List?) ?? [];
        for (final r in rows) {
          await txn.insert(t, Map<String, Object?>.from(r as Map));
        }
      }
    });
    onWrite?.call();
  }

  @override
  Future<ShopSnapshot> getSnapshot() async {
    final db = await _database.db;
    return ShopSnapshot(
      categories: (await db.query('categories')).map(Category.fromMap).toList(),
      products: (await db.query('products')).map(Product.fromMap).toList(),
      parties: (await db.query('parties')).map(Party.fromMap).toList(),
      invoices: (await db.query('invoices')).map(Invoice.fromMap).toList(),
      invoiceItems:
          (await db.query('invoice_items')).map(InvoiceItem.fromMap).toList(),
      expenses: (await db.query('expenses')).map(Expense.fromMap).toList(),
    );
  }

  @override
  Future<void> mergeSnapshot(ShopSnapshot snapshot) async {
    await _mergeRows('categories', snapshot.categories.map((e) => e.toMap()));
    await _mergeRows('products', snapshot.products.map((e) => e.toMap()));
    await _mergeRows('parties', snapshot.parties.map((e) => e.toMap()));
    await _mergeRows('invoices', snapshot.invoices.map((e) => e.toMap()));
    await _mergeRows(
        'invoice_items', snapshot.invoiceItems.map((e) => e.toMap()));
    await _mergeRows('expenses', snapshot.expenses.map((e) => e.toMap()));
  }

  /// Inserts/updates raw rows, keeping whichever version (local or given)
  /// has the newer `updated_at` - used when merging data pulled from the
  /// cloud, so a stale pull never overwrites a newer local edit.
  Future<void> _mergeRows(
      String table, Iterable<Map<String, Object?>> rows) async {
    final list = rows.toList();
    if (list.isEmpty) return;
    final db = await _database.db;
    await db.transaction((txn) async {
      for (final row in list) {
        final id = row['id'];
        final incomingUpdatedAt = (row['updated_at'] as num?)?.toInt() ?? 0;
        final existing =
            await txn.query(table, where: 'id = ?', whereArgs: [id], limit: 1);
        if (existing.isEmpty) {
          await txn.insert(table, row,
              conflictAlgorithm: ConflictAlgorithm.replace);
          continue;
        }
        final localUpdatedAt =
            (existing.first['updated_at'] as num?)?.toInt() ?? 0;
        if (incomingUpdatedAt > localUpdatedAt) {
          await txn.update(table, row, where: 'id = ?', whereArgs: [id]);
        }
      }
    });
  }

  @override
  Future<void> wipeAll() async {
    final db = await _database.db;
    await db.transaction((txn) async {
      for (final t in kSyncTables) {
        await txn.delete(t);
      }
    });
  }
}

extension _CategoryWithUpdatedAt on Category {
  Category copyWithUpdatedAt(int t) =>
      Category(id: id, name: name, updatedAt: t);
}

extension _ProductWithUpdatedAt on Product {
  Product copyWithUpdatedAt(int t) => Product(
        id: id,
        name: name,
        barcode: barcode,
        categoryId: categoryId,
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        quantity: quantity,
        createdAt: createdAt,
        purchaseUnit: purchaseUnit,
        unitFactor: unitFactor,
        unitName: unitName,
        updatedAt: t,
      );
}

extension _PartyWithUpdatedAt on Party {
  Party copyWithUpdatedAt(int t) => Party(
        id: id,
        name: name,
        phone: phone,
        kind: kind,
        balance: balance,
        updatedAt: t,
      );
}

extension _InvoiceWithUpdatedAt on Invoice {
  Invoice copyWithUpdatedAt(int t) => Invoice(
        id: id,
        kind: kind,
        partyId: partyId,
        total: total,
        paid: paid,
        discount: discount,
        date: date,
        notes: notes,
        updatedAt: t,
      );
}

extension _InvoiceItemWithUpdatedAt on InvoiceItem {
  InvoiceItem copyWithUpdatedAt(int t) => InvoiceItem(
        id: id,
        invoiceId: invoiceId,
        productId: productId,
        productName: productName,
        qty: qty,
        buyPrice: buyPrice,
        sellPrice: sellPrice,
        updatedAt: t,
      );
}

extension _ExpenseWithUpdatedAt on Expense {
  Expense copyWithUpdatedAt(int t) => Expense(
        id: id,
        title: title,
        amount: amount,
        date: date,
        notes: notes,
        updatedAt: t,
      );
}
