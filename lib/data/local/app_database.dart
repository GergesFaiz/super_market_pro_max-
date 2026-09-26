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
      version: 4,
      onCreate: (db, version) async {
        await _createV4(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE products ADD COLUMN purchase_unit TEXT DEFAULT \'\'');
          await db.execute(
              'ALTER TABLE products ADD COLUMN unit_factor REAL DEFAULT 1');
          await db.execute(
              'ALTER TABLE products ADD COLUMN unit_name TEXT DEFAULT \'\'');
        }
        if (oldVersion < 3) {
          await db.execute('''
          CREATE TABLE expenses(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            date INTEGER NOT NULL,
            notes TEXT
          )''');
        }
        if (oldVersion < 4) {
          for (final table in [
            'categories',
            'products',
            'parties',
            'invoices',
            'invoice_items',
            'expenses',
          ]) {
            await db.execute(
                'ALTER TABLE $table ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0');
          }
        }
      },
    );
  }

  Future<void> _createV4(Database db) async {
    await db.execute('''
          CREATE TABLE categories(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            updated_at INTEGER NOT NULL DEFAULT 0
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
            created_at INTEGER NOT NULL,
            purchase_unit TEXT DEFAULT '',
            unit_factor REAL DEFAULT 1,
            unit_name TEXT DEFAULT '',
            updated_at INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE parties(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            kind TEXT NOT NULL,
            balance REAL NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0
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
            notes TEXT,
            updated_at INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE invoice_items(
            id TEXT PRIMARY KEY,
            invoice_id TEXT NOT NULL,
            product_id TEXT,
            product_name TEXT NOT NULL,
            qty REAL NOT NULL,
            buy_price REAL NOT NULL,
            sell_price REAL NOT NULL,
            updated_at INTEGER NOT NULL DEFAULT 0
          )''');
        await db.execute('''
          CREATE TABLE expenses(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            date INTEGER NOT NULL,
            notes TEXT,
            updated_at INTEGER NOT NULL DEFAULT 0
          )''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
