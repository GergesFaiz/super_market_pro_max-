import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/shop_models.dart';

/// Single repository over SQLite for the whole shop.
class ShopRepository {
  ShopRepository({AppDatabase? database}) : _database = database ?? AppDatabase.instance;
  final AppDatabase _database;

  // ── Categories ──
  Future<List<Category>> getCategories() async {
    final db = await _database.db;
    final rows = await db.query('categories', orderBy: 'name');
    return rows.map(Category.fromMap).toList();
  }

  Future<void> addCategory(Category c) async {
    final db = await _database.db;
    await db.insert('categories', c.toMap());
  }

  Future<void> deleteCategory(String id) async {
    final db = await _database.db;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
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
      p.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteProduct(String id) async {
    final db = await _database.db;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
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
    await db.insert('parties', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteParty(String id) async {
    final db = await _database.db;
    await db.delete('parties', where: 'id = ?', whereArgs: [id]);
  }

  // ── Invoices (sale/purchase) ──
  Future<void> saveInvoice(Invoice invoice, List<InvoiceItem> items) async {
    final db = await _database.db;
    await db.transaction((txn) async {
      await txn.insert('invoices', invoice.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('invoice_items',
          where: 'invoice_id = ?', whereArgs: [invoice.id]);
      for (final it in items) {
        await txn.insert('invoice_items', it.toMap());
      }
      // Adjust stock + party balance.
      for (final it in items) {
        if (it.productId != null) {
          final sign = invoice.kind == 'sale' ? -1 : 1;
          await txn.rawUpdate(
            'UPDATE products SET quantity = quantity + ? WHERE id = ?',
            [sign * it.qty, it.productId],
          );
        }
      }
      if (invoice.partyId != null) {
        final delta = invoice.kind == 'sale'
            ? invoice.remaining
            : -invoice.remaining;
        await txn.rawUpdate(
          'UPDATE parties SET balance = balance + ? WHERE id = ?',
          [delta, invoice.partyId],
        );
      }
    });
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

  // ── Backup: export/import all tables as JSON ──
  Future<String> exportJson() async {
    final db = await _database.db;
    final data = <String, Object>{};
    for (final t in [
      'categories',
      'products',
      'parties',
      'invoices',
      'invoice_items'
    ]) {
      data[t] = await db.query(t);
    }
    return jsonEncode(data);
  }

  Future<void> importJson(String json) async {
    final db = await _database.db;
    final data = jsonDecode(json) as Map<String, dynamic>;
    await db.transaction((txn) async {
      for (final t in [
        'categories',
        'products',
        'parties',
        'invoices',
        'invoice_items'
      ]) {
        await txn.delete(t);
        final rows = (data[t] as List?) ?? [];
        for (final r in rows) {
          await txn.insert(t, Map<String, Object?>.from(r as Map));
        }
      }
    });
  }
}
