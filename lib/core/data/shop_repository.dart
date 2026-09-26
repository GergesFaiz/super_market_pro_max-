import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/shop_models.dart';

const kSyncTables = [
  'categories',
  'products',
  'parties',
  'invoices',
  'invoice_items',
  'expenses',
];

/// Single repository over SQLite for the whole shop.
class ShopRepository {
  ShopRepository({AppDatabase? database, this.onWrite})
      : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  /// Called after any mutating operation, so a sync service can react
  /// (e.g. push the change to the cloud when online).
  final void Function()? onWrite;

  int get _now => DateTime.now().millisecondsSinceEpoch;

  // ── Categories ──
  Future<List<Category>> getCategories() async {
    final db = await _database.db;
    final rows = await db.query('categories', orderBy: 'name');
    return rows.map(Category.fromMap).toList();
  }

  Future<void> addCategory(Category c) async {
    final db = await _database.db;
    await db.insert('categories', c.copyWithUpdatedAt(_now).toMap());
    onWrite?.call();
  }

  Future<void> deleteCategory(String id) async {
    final db = await _database.db;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    onWrite?.call();
  }

  // ── Products ──
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

  Future<void> upsertProduct(Product p) async {
    final db = await _database.db;
    await db.insert(
      'products',
      p.copyWithUpdatedAt(_now).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    onWrite?.call();
  }

  Future<void> deleteProduct(String id) async {
    final db = await _database.db;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
    onWrite?.call();
  }

  Future<List<Product>> lowStock(double threshold) async {
    final db = await _database.db;
    final rows = await db.query('products',
        where: 'quantity <= ?', whereArgs: [threshold], orderBy: 'quantity');
    return rows.map(Product.fromMap).toList();
  }

  // ── Parties ──
  Future<List<Party>> getParties(String kind) async {
    final db = await _database.db;
    final rows = await db.query('parties',
        where: 'kind = ?', whereArgs: [kind], orderBy: 'name');
    return rows.map(Party.fromMap).toList();
  }

  Future<void> upsertParty(Party p) async {
    final db = await _database.db;
    await db.insert('parties', p.copyWithUpdatedAt(_now).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    onWrite?.call();
  }

  Future<void> deleteParty(String id) async {
    final db = await _database.db;
    await db.delete('parties', where: 'id = ?', whereArgs: [id]);
    onWrite?.call();
  }

  // ── Invoices (sale/purchase) ──
  Future<void> saveInvoice(Invoice invoice, List<InvoiceItem> items) async {
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
      // Adjust stock + party balance.
      for (final it in items) {
        if (it.productId != null) {
          final sign = invoice.kind == 'sale' ? -1 : 1;
          await txn.rawUpdate(
            'UPDATE products SET quantity = quantity + ?, updated_at = ? WHERE id = ?',
            [sign * it.qty, now, it.productId],
          );
        }
      }
      if (invoice.partyId != null) {
        final delta = invoice.kind == 'sale'
            ? invoice.remaining
            : -invoice.remaining;
        await txn.rawUpdate(
          'UPDATE parties SET balance = balance + ?, updated_at = ? WHERE id = ?',
          [delta, now, invoice.partyId],
        );
      }
    });
    onWrite?.call();
  }

  Future<List<Invoice>> getInvoices(String kind, {int limit = 100}) async {
    final db = await _database.db;
    final rows = await db.query('invoices',
        where: 'kind = ?',
        whereArgs: [kind],
        orderBy: 'date DESC',
        limit: limit);
    return rows.map(Invoice.fromMap).toList();
  }

  Future<List<Invoice>> getInvoicesInRange(int from, int to) async {
    final db = await _database.db;
    final rows = await db.query('invoices',
        where: 'date >= ? AND date < ?',
        whereArgs: [from, to],
        orderBy: 'date DESC');
    return rows.map(Invoice.fromMap).toList();
  }

  Future<List<InvoiceItem>> getItems(String invoiceId) async {
    final db = await _database.db;
    final rows = await db.query('invoice_items',
        where: 'invoice_id = ?', whereArgs: [invoiceId]);
    return rows.map(InvoiceItem.fromMap).toList();
  }

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
  Future<List<Expense>> getExpensesInRange(int from, int to) async {
    final db = await _database.db;
    final rows = await db.query('expenses',
        where: 'date >= ? AND date < ?',
        whereArgs: [from, to],
        orderBy: 'date DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<void> addExpense(Expense e) async {
    final db = await _database.db;
    await db.insert('expenses', e.copyWithUpdatedAt(_now).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    onWrite?.call();
  }

  Future<void> deleteExpense(String id) async {
    final db = await _database.db;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    onWrite?.call();
  }

  // ── Backup: export/import all tables as JSON ──
  Future<String> exportJson() async {
    final db = await _database.db;
    final data = <String, Object>{};
    for (final t in kSyncTables) {
      data[t] = await db.query(t);
    }
    return jsonEncode(data);
  }

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

  // ── Cloud sync helpers ──

  /// All rows of [table] as raw maps, for pushing to the cloud.
  Future<List<Map<String, Object?>>> tableRows(String table) async {
    final db = await _database.db;
    return db.query(table);
  }

  /// Inserts/updates raw rows coming from the cloud, keeping whichever
  /// version (local or remote) has the newer `updated_at`.
  Future<void> mergeRows(String table, List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final db = await _database.db;
    await db.transaction((txn) async {
      for (final row in rows) {
        final id = row['id'];
        final remoteUpdatedAt = (row['updated_at'] as num?)?.toInt() ?? 0;
        final existing = await txn
            .query(table, where: 'id = ?', whereArgs: [id], limit: 1);
        if (existing.isEmpty) {
          await txn.insert(table, row,
              conflictAlgorithm: ConflictAlgorithm.replace);
          continue;
        }
        final localUpdatedAt =
            (existing.first['updated_at'] as num?)?.toInt() ?? 0;
        if (remoteUpdatedAt > localUpdatedAt) {
          await txn.update(table, row, where: 'id = ?', whereArgs: [id]);
        }
      }
    });
  }
}

extension _WithUpdatedAt on Category {
  Category copyWithUpdatedAt(int t) => Category(id: id, name: name, updatedAt: t);
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
