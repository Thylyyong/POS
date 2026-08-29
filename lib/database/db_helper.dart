import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  static const String _dbName = 'omni_pos.db';
  static const int _dbVersion = 4;

  static DbHelper? _instance;
  static Database? _database;

  DbHelper._internal();

  factory DbHelper() {
    _instance ??= DbHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    // Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT,
        color_hex TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Subcategories Table
    await db.execute('''
      CREATE TABLE subcategories (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
      )
    ''');

    // Products Table
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        subcategory_id TEXT,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        cost REAL NOT NULL DEFAULT 0.0,
        barcode TEXT,
        image_path TEXT,
        in_stock INTEGER NOT NULL DEFAULT 1,
        color_hex TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
        FOREIGN KEY (subcategory_id) REFERENCES subcategories (id) ON DELETE SET NULL
      )
    ''');

    // Dining Tables Table (v3)
    await db.execute('''
      CREATE TABLE dining_tables (
        id TEXT PRIMARY KEY,
        table_number TEXT NOT NULL,
        name TEXT NOT NULL,
        capacity INTEGER NOT NULL DEFAULT 4,
        status TEXT NOT NULL DEFAULT 'AVAILABLE',
        type TEXT NOT NULL DEFAULT 'STANDARD',
        current_order_id TEXT,
        customer_name TEXT,
        order_total REAL,
        created_at TEXT NOT NULL
      )
    ''');

    // Orders Table (v3: includes table, customer, order_number, order_type)
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        receipt_no TEXT UNIQUE NOT NULL,
        order_number TEXT,
        table_id TEXT,
        table_number TEXT,
        customer_name TEXT,
        order_type TEXT NOT NULL DEFAULT 'DINE_IN',
        subtotal REAL NOT NULL,
        discount_amount REAL NOT NULL DEFAULT 0.0,
        discount_percent REAL NOT NULL DEFAULT 0.0,
        tax_amount REAL NOT NULL DEFAULT 0.0,
        tax_rate REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        cash_tendered REAL DEFAULT 0.0,
        change_amount REAL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'COMPLETED',
        created_at TEXT NOT NULL
      )
    ''');

    // Order Items Table
    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    // Store Settings Table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Daily Reports Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_reports (
        id TEXT PRIMARY KEY,
        report_date TEXT NOT NULL,
        total_revenue REAL NOT NULL DEFAULT 0.0,
        total_orders INTEGER NOT NULL DEFAULT 0,
        cash_revenue REAL NOT NULL DEFAULT 0.0,
        qr_revenue REAL NOT NULL DEFAULT 0.0,
        top_selling_item TEXT,
        total_tax REAL NOT NULL DEFAULT 0.0,
        generated_at TEXT NOT NULL
      )
    ''');

    // Receipt Logs Table (v2: includes receipt_file_path)
    await db.execute('''
      CREATE TABLE receipt_logs (
        id TEXT PRIMARY KEY,
        receipt_no TEXT NOT NULL,
        order_id TEXT NOT NULL,
        action TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        is_success INTEGER NOT NULL DEFAULT 1,
        error_message TEXT,
        receipt_file_path TEXT,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_products_category ON products (category_id)');
    await db.execute('CREATE INDEX idx_products_barcode ON products (barcode)');
    await db.execute('CREATE INDEX idx_orders_created ON orders (created_at)');
    await db.execute('CREATE INDEX idx_orders_status ON orders (status)');
    await db.execute('CREATE INDEX idx_order_items_order ON order_items (order_id)');
    await db.execute('CREATE INDEX idx_receipt_logs_order ON receipt_logs (order_id)');
    await db.execute('CREATE INDEX idx_tables_status ON dining_tables (status)');
    await db.execute('CREATE INDEX idx_daily_reports_date ON daily_reports (report_date)');

    // Seed Initial Data
    await _seedInitialData(db);
  }

  FutureOr<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE receipt_logs ADD COLUMN receipt_file_path TEXT',
      );
    }
    if (oldVersion < 3) {
      // Create dining_tables table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS dining_tables (
          id TEXT PRIMARY KEY,
          table_number TEXT NOT NULL,
          name TEXT NOT NULL,
          capacity INTEGER NOT NULL DEFAULT 4,
          status TEXT NOT NULL DEFAULT 'AVAILABLE',
          type TEXT NOT NULL DEFAULT 'STANDARD',
          current_order_id TEXT,
          customer_name TEXT,
          order_total REAL,
          created_at TEXT NOT NULL
        )
      ''');

      // Add columns to orders
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN order_number TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN table_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN table_number TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN customer_name TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE orders ADD COLUMN order_type TEXT DEFAULT "DINE_IN"');
      } catch (_) {}

      // Create daily_reports table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_reports (
          id TEXT PRIMARY KEY,
          report_date TEXT NOT NULL,
          total_revenue REAL NOT NULL DEFAULT 0.0,
          total_orders INTEGER NOT NULL DEFAULT 0,
          cash_revenue REAL NOT NULL DEFAULT 0.0,
          qr_revenue REAL NOT NULL DEFAULT 0.0,
          top_selling_item TEXT,
          total_tax REAL NOT NULL DEFAULT 0.0,
          generated_at TEXT NOT NULL
        )
      ''');

      // Seed default tables
      await _seedDefaultTables(db);
    }
    if (oldVersion < 4) {
      // Add description column to products (nullable, safe)
      try {
        await db.execute('ALTER TABLE products ADD COLUMN description TEXT');
      } catch (_) {}
    }
  }

  Future<void> _seedInitialData(Database db) async {
    // 1. Categories
    final categories = [
      {'id': 'cat_coffee', 'name': 'Coffee & Tea', 'icon': 'local_cafe', 'color_hex': '0xFF3B82F6', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'cat_burgers', 'name': 'Burgers & Sandwiches', 'icon': 'lunch_dining', 'color_hex': '0xFF10B981', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'cat_mains', 'name': 'Asian & Western Mains', 'icon': 'restaurant', 'color_hex': '0xFFF59E0B', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'cat_desserts', 'name': 'Pastries & Desserts', 'icon': 'cake', 'color_hex': '0xFF8B5CF6', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'cat_drinks', 'name': 'Beverages & Frappes', 'icon': 'local_bar', 'color_hex': '0xFFEC4899', 'created_at': DateTime.now().toIso8601String()},
    ];

    for (var c in categories) {
      await db.insert('categories', c, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 2. Subcategories
    final subcategories = [
      {'id': 'sub_hot_coffee', 'category_id': 'cat_coffee', 'name': 'Hot Espresso', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'sub_iced_coffee', 'category_id': 'cat_coffee', 'name': 'Iced Coffee', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'sub_burgers', 'category_id': 'cat_burgers', 'name': 'Gourmet Burgers', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'sub_fries', 'category_id': 'cat_burgers', 'name': 'Sides & Snacks', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'sub_rice', 'category_id': 'cat_mains', 'name': 'Signature Bowls', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'sub_pasta', 'category_id': 'cat_mains', 'name': 'Handmade Pasta', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'sub_cakes', 'category_id': 'cat_desserts', 'name': 'Artisan Cakes', 'created_at': DateTime.now().toIso8601String()},
      {'id': 'sub_smoothies', 'category_id': 'cat_drinks', 'name': 'Fresh Smoothies', 'created_at': DateTime.now().toIso8601String()},
    ];

    for (var s in subcategories) {
      await db.insert('subcategories', s, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 3. Products
    final products = [
      {'id': 'prod_espresso', 'category_id': 'cat_coffee', 'subcategory_id': 'sub_hot_coffee', 'name': 'Double Espresso', 'price': 2.75, 'cost': 0.80, 'barcode': '100001', 'color_hex': '0xFF3B82F6', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_americano', 'category_id': 'cat_coffee', 'subcategory_id': 'sub_hot_coffee', 'name': 'Caffe Americano', 'price': 3.25, 'cost': 0.90, 'barcode': '100002', 'color_hex': '0xFF3B82F6', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_latte', 'category_id': 'cat_coffee', 'subcategory_id': 'sub_hot_coffee', 'name': 'Vanilla Caffe Latte', 'price': 4.50, 'cost': 1.20, 'barcode': '100003', 'color_hex': '0xFF3B82F6', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_cappuccino', 'category_id': 'cat_coffee', 'subcategory_id': 'sub_hot_coffee', 'name': 'Caramel Cappuccino', 'price': 4.75, 'cost': 1.30, 'barcode': '100004', 'color_hex': '0xFF3B82F6', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_iced_latte', 'category_id': 'cat_coffee', 'subcategory_id': 'sub_iced_coffee', 'name': 'Iced Spanish Latte', 'price': 5.00, 'cost': 1.50, 'barcode': '100005', 'color_hex': '0xFF3B82F6', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_matcha', 'category_id': 'cat_coffee', 'subcategory_id': 'sub_iced_coffee', 'name': 'Iced Uji Matcha Latte', 'price': 5.50, 'cost': 1.80, 'barcode': '100006', 'color_hex': '0xFF3B82F6', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},

      {'id': 'prod_wagyu_burger', 'category_id': 'cat_burgers', 'subcategory_id': 'sub_burgers', 'name': 'Truffle Wagyu Burger', 'price': 12.50, 'cost': 4.80, 'barcode': '200001', 'color_hex': '0xFF10B981', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_crispy_chicken', 'category_id': 'cat_burgers', 'subcategory_id': 'sub_burgers', 'name': 'Spicy Crispy Chicken Burger', 'price': 9.75, 'cost': 3.20, 'barcode': '200002', 'color_hex': '0xFF10B981', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_club_sandwich', 'category_id': 'cat_burgers', 'subcategory_id': 'sub_burgers', 'name': 'Smoked Turkey Club', 'price': 8.50, 'cost': 2.80, 'barcode': '200003', 'color_hex': '0xFF10B981', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_truffle_fries', 'category_id': 'cat_burgers', 'subcategory_id': 'sub_fries', 'name': 'Parmesan Truffle Fries', 'price': 4.95, 'cost': 1.40, 'barcode': '200004', 'color_hex': '0xFF10B981', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_onion_rings', 'category_id': 'cat_burgers', 'subcategory_id': 'sub_fries', 'name': 'Crispy Beer Onion Rings', 'price': 4.25, 'cost': 1.10, 'barcode': '200005', 'color_hex': '0xFF10B981', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},

      {'id': 'prod_pad_thai', 'category_id': 'cat_mains', 'subcategory_id': 'sub_rice', 'name': 'Royal Prawn Pad Thai', 'price': 11.00, 'cost': 3.90, 'barcode': '300001', 'color_hex': '0xFFF59E0B', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_teriyaki_bowl', 'category_id': 'cat_mains', 'subcategory_id': 'sub_rice', 'name': 'Salmon Teriyaki Bowl', 'price': 13.50, 'cost': 5.10, 'barcode': '300002', 'color_hex': '0xFFF59E0B', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_carbonara', 'category_id': 'cat_mains', 'subcategory_id': 'sub_pasta', 'name': 'Classic Guanciale Carbonara', 'price': 12.00, 'cost': 4.00, 'barcode': '300003', 'color_hex': '0xFFF59E0B', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},

      {'id': 'prod_cheesecake', 'category_id': 'cat_desserts', 'subcategory_id': 'sub_cakes', 'name': 'Basque Burnt Cheesecake', 'price': 6.25, 'cost': 2.00, 'barcode': '400001', 'color_hex': '0xFF8B5CF6', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_tiramisu', 'category_id': 'cat_desserts', 'subcategory_id': 'sub_cakes', 'name': 'Classic Italian Tiramisu', 'price': 6.75, 'cost': 2.20, 'barcode': '400002', 'color_hex': '0xFF8B5CF6', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_croissant', 'category_id': 'cat_desserts', 'subcategory_id': 'sub_cakes', 'name': 'Almond Butter Croissant', 'price': 3.95, 'cost': 1.10, 'barcode': '400003', 'color_hex': '0xFF8B5CF6', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},

      {'id': 'prod_mango_smoothie', 'category_id': 'cat_drinks', 'subcategory_id': 'sub_smoothies', 'name': 'Tropical Mango Passion Smoothie', 'price': 5.25, 'cost': 1.60, 'barcode': '500001', 'color_hex': '0xFFEC4899', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_berry_blast', 'category_id': 'cat_drinks', 'subcategory_id': 'sub_smoothies', 'name': 'Wild Berry Acai Frappe', 'price': 5.75, 'cost': 1.75, 'barcode': '500002', 'color_hex': '0xFFEC4899', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
      {'id': 'prod_sparkling_lemonade', 'category_id': 'cat_drinks', 'subcategory_id': 'sub_smoothies', 'name': 'Sparkling Mint Lemonade', 'price': 4.25, 'cost': 0.95, 'barcode': '500003', 'color_hex': '0xFFEC4899', 'in_stock': 1, 'created_at': DateTime.now().toIso8601String()},
    ];

    for (var p in products) {
      await db.insert('products', p, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 4. Default Store Settings
    final defaultSettings = {
      'store_name': 'Gourmet Bistro POS',
      'store_address': '123 Boulevard St, Suite 100',
      'store_phone': '+1 (555) 019-2834',
      'store_email': 'contact@gourmetbistro.com',
      'currency_symbol': '\$',
      'default_tax_rate': '10.0',
      'footer_note': 'Thank you for dining with us!\nPlease visit again.',
      'logo_path': '',
      'auto_print_on_payment': '1',
      'auto_kick_cash_drawer': '1',
      'cfd_enabled': '1',
      'is_paper_size_80mm': '1',
      'printer_ip_or_address': '192.168.1.100',
      'qr_payload_template': 'https://pay.restaurant.com/pos?order=',
    };

    for (var entry in defaultSettings.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // 5. Seed Tables
    await _seedDefaultTables(db);

    // 6. Sample historical orders
    await _seedSampleOrders(db);
  }

  Future<void> _seedDefaultTables(Database db) async {
    final now = DateTime.now().toIso8601String();
    final defaultTables = [
      {'id': 'tbl_01', 'table_number': 'T01', 'name': 'Window Table 1', 'capacity': 4, 'status': 'AVAILABLE', 'type': 'STANDARD', 'created_at': now},
      {'id': 'tbl_02', 'table_number': 'T02', 'name': 'Window Table 2', 'capacity': 4, 'status': 'AVAILABLE', 'type': 'STANDARD', 'created_at': now},
      {'id': 'tbl_03', 'table_number': 'T03', 'name': 'Cozy Corner', 'capacity': 2, 'status': 'AVAILABLE', 'type': 'STANDARD', 'created_at': now},
      {'id': 'tbl_04', 'table_number': 'T04', 'name': 'Bistro Table 4', 'capacity': 2, 'status': 'AVAILABLE', 'type': 'STANDARD', 'created_at': now},
      {'id': 'tbl_05', 'table_number': 'T05', 'name': 'Central Booth', 'capacity': 6, 'status': 'AVAILABLE', 'type': 'STANDARD', 'created_at': now},
      {'id': 'tbl_06', 'table_number': 'T06', 'name': 'Family Table 6', 'capacity': 6, 'status': 'AVAILABLE', 'type': 'STANDARD', 'created_at': now},
      {'id': 'tbl_07', 'table_number': 'T07', 'name': 'High Top 7', 'capacity': 4, 'status': 'AVAILABLE', 'type': 'STANDARD', 'created_at': now},
      {'id': 'tbl_08', 'table_number': 'T08', 'name': 'Large Group Table', 'capacity': 8, 'status': 'AVAILABLE', 'type': 'STANDARD', 'created_at': now},
      {'id': 'tbl_vip1', 'table_number': 'VIP-1', 'name': 'Royal Executive Room', 'capacity': 10, 'status': 'AVAILABLE', 'type': 'VIP_ROOM', 'created_at': now},
      {'id': 'tbl_vip2', 'table_number': 'VIP-2', 'name': 'Emerald Private Suite', 'capacity': 8, 'status': 'AVAILABLE', 'type': 'VIP_ROOM', 'created_at': now},
      {'id': 'tbl_patio1', 'table_number': 'Patio-1', 'name': 'Outdoor Garden 1', 'capacity': 4, 'status': 'AVAILABLE', 'type': 'OUTDOOR', 'created_at': now},
      {'id': 'tbl_patio2', 'table_number': 'Patio-2', 'name': 'Outdoor Garden 2', 'capacity': 4, 'status': 'AVAILABLE', 'type': 'OUTDOOR', 'created_at': now},
    ];

    for (var tbl in defaultTables) {
      await db.insert('dining_tables', tbl, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _seedSampleOrders(Database db) async {
    final now = DateTime.now();

    final sampleOrders = [
      {
        'id': 'ord_demo_01',
        'receipt_no': 'REC-DEMO-001',
        'order_number': '001',
        'table_number': 'T01',
        'customer_name': 'Michael S.',
        'order_type': 'DINE_IN',
        'subtotal': 21.75,
        'discount_amount': 2.00,
        'discount_percent': 0.0,
        'tax_amount': 1.98,
        'tax_rate': 10.0,
        'total_amount': 21.73,
        'payment_method': 'CASH',
        'cash_tendered': 30.00,
        'change_amount': 8.27,
        'status': 'COMPLETED',
        'created_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'items': [
          {'id': 'item_01_1', 'product_id': 'prod_wagyu_burger', 'product_name': 'Truffle Wagyu Burger', 'quantity': 1, 'unit_price': 12.50, 'total_price': 12.50},
          {'id': 'item_01_2', 'product_id': 'prod_truffle_fries', 'product_name': 'Parmesan Truffle Fries', 'quantity': 1, 'unit_price': 4.95, 'total_price': 4.95},
          {'id': 'item_01_3', 'product_id': 'prod_latte', 'product_name': 'Vanilla Caffe Latte', 'quantity': 1, 'unit_price': 4.50, 'total_price': 4.50},
        ],
      },
      {
        'id': 'ord_demo_02',
        'receipt_no': 'REC-DEMO-002',
        'order_number': '002',
        'table_number': 'VIP-1',
        'customer_name': 'Sarah Connor',
        'order_type': 'DINE_IN',
        'subtotal': 31.00,
        'discount_amount': 0.0,
        'discount_percent': 0.0,
        'tax_amount': 3.10,
        'tax_rate': 10.0,
        'total_amount': 34.10,
        'payment_method': 'QR CODE',
        'cash_tendered': 34.10,
        'change_amount': 0.0,
        'status': 'COMPLETED',
        'created_at': now.subtract(const Duration(hours: 1, minutes: 20)).toIso8601String(),
        'items': [
          {'id': 'item_02_1', 'product_id': 'prod_pad_thai', 'product_name': 'Royal Prawn Pad Thai', 'quantity': 2, 'unit_price': 11.00, 'total_price': 22.00},
          {'id': 'item_02_2', 'product_id': 'prod_matcha', 'product_name': 'Iced Uji Matcha Latte', 'quantity': 1, 'unit_price': 5.50, 'total_price': 5.50},
          {'id': 'item_02_3', 'product_id': 'prod_sparkling_lemonade', 'product_name': 'Sparkling Mint Lemonade', 'quantity': 1, 'unit_price': 4.25, 'total_price': 4.25},
        ],
      },
      {
        'id': 'ord_demo_03',
        'receipt_no': 'REC-DEMO-003',
        'order_number': '003',
        'table_number': 'Takeaway',
        'customer_name': 'David Miller',
        'order_type': 'TAKEAWAY',
        'subtotal': 18.00,
        'discount_amount': 1.80,
        'discount_percent': 10.0,
        'tax_amount': 1.62,
        'tax_rate': 10.0,
        'total_amount': 17.82,
        'payment_method': 'CASH',
        'cash_tendered': 20.00,
        'change_amount': 2.18,
        'status': 'COMPLETED',
        'created_at': now.subtract(const Duration(days: 1, hours: 2)).toIso8601String(),
        'items': [
          {'id': 'item_03_1', 'product_id': 'prod_cheesecake', 'product_name': 'Basque Burnt Cheesecake', 'quantity': 2, 'unit_price': 6.25, 'total_price': 12.50},
          {'id': 'item_03_2', 'product_id': 'prod_matcha', 'product_name': 'Iced Uji Matcha Latte', 'quantity': 1, 'unit_price': 5.50, 'total_price': 5.50},
        ],
      },
    ];

    for (var ord in sampleOrders) {
      final items = ord['items'] as List<Map<String, dynamic>>;
      final orderMap = Map<String, dynamic>.from(ord)..remove('items');
      await db.insert('orders', orderMap, conflictAlgorithm: ConflictAlgorithm.ignore);

      for (var item in items) {
        final itemMap = Map<String, dynamic>.from(item)..['order_id'] = ord['id'];
        await db.insert('order_items', itemMap, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await db.insert('receipt_logs', {
        'id': 'log_${ord['id']}',
        'receipt_no': ord['receipt_no'],
        'order_id': ord['id'],
        'action': 'INITIAL_PRINT',
        'timestamp': ord['created_at'],
        'is_success': 1,
        'error_message': null,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}
