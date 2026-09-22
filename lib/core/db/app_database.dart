import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Offline-first SQLite database for the shop.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      join(dir, 'super_market_pro_max.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE products(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            barcode TEXT,
            category_id TEXT,
            buy_price REAL NOT NULL,
            sell_price REAL NOT NULL,
            quantity REAL NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE parties(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            kind TEXT NOT NULL,
            balance REAL NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE invoices(
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            party_id TEXT,
            total REAL NOT NULL,
            paid REAL NOT NULL,
            discount REAL NOT NULL DEFAULT 0,
            date INTEGER NOT NULL,
            notes TEXT
          )''');
        await db.execute('''
          CREATE TABLE invoice_items(
            id TEXT PRIMARY KEY,
            invoice_id TEXT NOT NULL,
            product_id TEXT,
            product_name TEXT NOT NULL,
            qty REAL NOT NULL,
            buy_price REAL NOT NULL,
            sell_price REAL NOT NULL
          )''');
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
