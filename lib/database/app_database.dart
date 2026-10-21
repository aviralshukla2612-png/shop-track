import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;
    if (kIsWeb) {
      dbPath = 'shop_track_v1.db';
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(docDir.path, 'shop_track_v1.db');
    }

    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _onCreate,
        onOpen: (db) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_settings (
              key TEXT PRIMARY KEY,
              value TEXT
            )
          ''');
        },
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // 1. Master Products Table
    await db.execute('''
      CREATE TABLE master_products (
        id TEXT PRIMARY KEY,
        source_id TEXT,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        manufacturer TEXT,
        category TEXT NOT NULL,
        subcategory TEXT,
        variant TEXT,
        flavour TEXT,
        net_weight TEXT,
        net_volume TEXT,
        pack_size TEXT,
        units_per_carton INTEGER,
        barcode TEXT,
        mrp REAL,
        displayed_price REAL,
        currency TEXT DEFAULT 'INR',
        price_type TEXT,
        product_url TEXT,
        image_url TEXT,
        image_urls TEXT,
        local_image_path TEXT,
        source_name TEXT NOT NULL,
        source_document TEXT,
        source_page INTEGER,
        attribution TEXT,
        verification_status TEXT,
        last_verified_at TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_master_products_name ON master_products (name)');
    await db.execute('CREATE INDEX idx_master_products_brand ON master_products (brand)');
    await db.execute('CREATE INDEX idx_master_products_category ON master_products (category)');
    await db.execute('CREATE INDEX idx_master_products_barcode ON master_products (barcode)');

    // 2. Shop Inventory Table
    await db.execute('''
      CREATE TABLE inventory (
        id TEXT PRIMARY KEY,
        master_product_id TEXT,
        name TEXT NOT NULL,
        brand TEXT NOT NULL,
        category TEXT NOT NULL,
        subcategory TEXT,
        pack_size TEXT,
        barcode TEXT,
        purchase_price REAL NOT NULL,
        selling_price REAL NOT NULL,
        current_stock REAL NOT NULL,
        min_stock_level REAL DEFAULT 5.0,
        preferred_supplier_id TEXT,
        preferred_supplier_name TEXT,
        is_tobacco INTEGER DEFAULT 0,
        units_per_pack INTEGER DEFAULT 1,
        loose_selling_price REAL,
        image_url TEXT,
        local_image_path TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_inventory_name ON inventory (name)');
    await db.execute('CREATE INDEX idx_inventory_barcode ON inventory (barcode)');
    await db.execute('CREATE INDEX idx_inventory_category ON inventory (category)');

    // 3. Suppliers Table
    await db.execute('''
      CREATE TABLE suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        gst_number TEXT,
        current_balance REAL DEFAULT 0.0,
        created_at TEXT NOT NULL
      )
    ''');

    // 4. Sales Transactions Table
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL,
        created_at TEXT NOT NULL,
        customer_name TEXT,
        customer_phone TEXT,
        payment_method TEXT NOT NULL,
        subtotal REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        grand_total REAL NOT NULL,
        total_cost_basis REAL NOT NULL,
        gross_profit REAL NOT NULL,
        status TEXT DEFAULT 'completed',
        notes TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_sales_created_at ON sales (created_at)');

    // 5. Sale Items Table
    await db.execute('''
      CREATE TABLE sale_items (
        id TEXT PRIMARY KEY,
        sale_id TEXT NOT NULL,
        inventory_item_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        variant TEXT,
        quantity REAL NOT NULL,
        unit_selling_price REAL NOT NULL,
        unit_cost_basis REAL NOT NULL,
        discount REAL DEFAULT 0.0,
        line_total REAL NOT NULL,
        line_profit REAL NOT NULL,
        is_loose_stick INTEGER DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_sale_items_sale_id ON sale_items (sale_id)');
    await db.execute('CREATE INDEX idx_sale_items_inventory_id ON sale_items (inventory_item_id)');

    // 6. Purchases Orders & Inward Receipts Table
    await db.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        order_number TEXT NOT NULL,
        supplier_id TEXT,
        supplier_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        received_at TEXT,
        total_amount REAL NOT NULL,
        status TEXT DEFAULT 'received',
        invoice_ref TEXT,
        notes TEXT
      )
    ''');

    // 7. Purchase Items Table
    await db.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        inventory_item_id TEXT,
        product_name TEXT NOT NULL,
        variant TEXT,
        quantity REAL NOT NULL,
        unit_cost REAL NOT NULL,
        line_total REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
      )
    ''');

    // 8. Purchase Shopping List Table
    await db.execute('''
      CREATE TABLE purchase_list (
        id TEXT PRIMARY KEY,
        master_product_id TEXT,
        inventory_item_id TEXT,
        product_name TEXT NOT NULL,
        brand TEXT NOT NULL,
        variant TEXT,
        pack_size TEXT,
        requested_quantity REAL NOT NULL,
        estimated_unit_cost REAL NOT NULL,
        is_cost_confirmed INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        supplier_name TEXT,
        notes TEXT,
        image_url TEXT,
        local_image_path TEXT,
        added_at TEXT NOT NULL
      )
    ''');

    // 9. Operating Expenses Table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_mode TEXT DEFAULT 'Cash',
        expense_date TEXT NOT NULL,
        notes TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_expenses_date ON expenses (expense_date)');

    // 10. Stock Adjustments Table
    await db.execute('''
      CREATE TABLE stock_adjustments (
        id TEXT PRIMARY KEY,
        inventory_item_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity_change REAL NOT NULL,
        reason TEXT NOT NULL,
        cost_loss REAL NOT NULL,
        adjusted_at TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
