import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/invoice.dart';

const _defaultProducts = [
  'Cattle pro Meat +5',
  'Cattle pro Milk +12',
  'Cattle pro Milk +14',
  'Cattle pro customized',
];

class DbHelper {
  static final DbHelper _instance = DbHelper._internal();
  factory DbHelper() => _instance;
  DbHelper._internal();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'moosjan_invoices.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedProducts(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS saved_items (
              id         INTEGER PRIMARY KEY AUTOINCREMENT,
              item_name  TEXT    NOT NULL,
              last_price REAL    NOT NULL DEFAULT 0,
              use_count  INTEGER NOT NULL DEFAULT 1,
              UNIQUE(item_name COLLATE NOCASE)
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS products (
              id         INTEGER PRIMARY KEY AUTOINCREMENT,
              name       TEXT    NOT NULL,
              sort_order INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await _seedProducts(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE invoices (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number   TEXT    NOT NULL,
        date             TEXT    NOT NULL,
        sales_rep        TEXT,
        customer_name    TEXT    NOT NULL,
        customer_address TEXT,
        items_json       TEXT    NOT NULL,
        total            REAL    NOT NULL,
        notes            TEXT,
        created_at       TEXT    NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE saved_items (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        item_name  TEXT    NOT NULL,
        last_price REAL    NOT NULL DEFAULT 0,
        use_count  INTEGER NOT NULL DEFAULT 1,
        UNIQUE(item_name COLLATE NOCASE)
      )
    ''');
    await db.execute('''
      CREATE TABLE products (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT    NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _seedProducts(Database db) async {
    for (int i = 0; i < _defaultProducts.length; i++) {
      await db.insert('products', {
        'name': _defaultProducts[i],
        'sort_order': i,
      });
    }
  }

  // ── Invoices CRUD ─────────────────────────────────────

  Future<List<Invoice>> getAllInvoices() async {
    final d = await db;
    final rows = await d.query('invoices', orderBy: 'id DESC');
    return rows.map(Invoice.fromMap).toList();
  }

  Future<Invoice> insertInvoice(Invoice invoice) async {
    final d = await db;
    final id = await d.insert('invoices', invoice.toMap());
    await _upsertItemsFromInvoice(invoice.items);
    return invoice.copyWith(id: id);
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final d = await db;
    await d.update(
      'invoices',
      invoice.toMap(),
      where: 'id = ?',
      whereArgs: [invoice.id],
    );
    await _upsertItemsFromInvoice(invoice.items);
  }

  Future<void> deleteInvoice(int id) async {
    final d = await db;
    await d.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getNextInvoiceNumber() async {
    final d = await db;
    final result = await d.rawQuery(
      'SELECT MAX(CAST(invoice_number AS INTEGER)) AS max_num FROM invoices',
    );
    final maxNum = result.first['max_num'] as int?;
    return (maxNum ?? 2782) + 1;
  }

  // ── Products catalog ──────────────────────────────────

  Future<List<Product>> getAllProducts() async {
    final d = await db;
    final rows =
        await d.query('products', orderBy: 'sort_order ASC, id ASC');
    return rows.map(Product.fromMap).toList();
  }

  Future<Product> insertProduct(String name) async {
    final d = await db;
    final maxOrder = Sqflite.firstIntValue(await d.rawQuery(
            'SELECT MAX(sort_order) FROM products')) ??
        0;
    final id = await d.insert(
        'products', {'name': name.trim(), 'sort_order': maxOrder + 1});
    return Product(id: id, name: name.trim(), sortOrder: maxOrder + 1);
  }

  Future<void> deleteProduct(int id) async {
    final d = await db;
    await d.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorderProducts(List<Product> products) async {
    final d = await db;
    final batch = d.batch();
    for (int i = 0; i < products.length; i++) {
      batch.update(
        'products',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [products[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Saved items catalog ───────────────────────────────

  Future<void> _upsertItemsFromInvoice(List<InvoiceItem> items) async {
    final d = await db;
    for (final item in items) {
      if (item.itemName.trim().isEmpty) continue;
      await d.rawInsert('''
        INSERT INTO saved_items (item_name, last_price, use_count)
        VALUES (?, ?, 1)
        ON CONFLICT(item_name) DO UPDATE SET
          last_price = excluded.last_price,
          use_count  = use_count + 1
      ''', [item.itemName.trim(), item.priceEach]);
    }
  }

  Future<List<SavedItem>> getAllSavedItems() async {
    final d = await db;
    final rows = await d.query(
      'saved_items',
      orderBy: 'use_count DESC, item_name ASC',
    );
    return rows.map(SavedItem.fromMap).toList();
  }

  Future<void> deleteSavedItem(int id) async {
    final d = await db;
    await d.delete('saved_items', where: 'id = ?', whereArgs: [id]);
  }
}

// ── Models ────────────────────────────────────────────────

class Product {
  final int id;
  final String name;
  final int sortOrder;

  const Product({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
        id: m['id'] as int,
        name: m['name'] as String,
        sortOrder: m['sort_order'] as int,
      );
}

class SavedItem {
  final int id;
  final String itemName;
  final double lastPrice;
  final int useCount;

  const SavedItem({
    required this.id,
    required this.itemName,
    required this.lastPrice,
    required this.useCount,
  });

  factory SavedItem.fromMap(Map<String, dynamic> m) => SavedItem(
        id: m['id'] as int,
        itemName: m['item_name'] as String,
        lastPrice: (m['last_price'] as num).toDouble(),
        useCount: m['use_count'] as int,
      );
}
