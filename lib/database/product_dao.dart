import 'package:sqflite/sqflite.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/stock_audit_log_model.dart';
import 'db_helper.dart';

class ProductDao {
  final DbHelper _dbHelper = DbHelper();

  // --- Categories ---
  Future<List<Category>> getAllCategories() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('categories', orderBy: 'created_at ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<Category?> getCategoryById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Category.fromMap(maps.first);
    }
    return null;
  }

  Future<int> insertCategory(Category category) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateCategory(Category category) async {
    final db = await _dbHelper.database;
    return await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Subcategories ---
  Future<List<Subcategory>> getSubcategoriesByCategory(String categoryId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'subcategories',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => Subcategory.fromMap(m)).toList();
  }

  Future<List<Subcategory>> getAllSubcategories() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('subcategories', orderBy: 'created_at ASC');
    return maps.map((m) => Subcategory.fromMap(m)).toList();
  }

  Future<int> insertSubcategory(Subcategory subcategory) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'subcategories',
      subcategory.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateSubcategory(Subcategory subcategory) async {
    final db = await _dbHelper.database;
    return await db.update(
      'subcategories',
      subcategory.toMap(),
      where: 'id = ?',
      whereArgs: [subcategory.id],
    );
  }

  Future<int> deleteSubcategory(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'subcategories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Products ---
  Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('products', orderBy: 'name ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<List<Product>> getProductsByCategory(String categoryId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getProductById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await _dbHelper.database;
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'barcode = ? OR id = ?',
      whereArgs: [trimmed, trimmed],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Product>> searchProducts(String query, {String? categoryId}) async {
    final db = await _dbHelper.database;
    final cleanQuery = '%${query.trim()}%';

    String whereClause;
    List<dynamic> whereArgs;

    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'ALL') {
      whereClause = 'category_id = ? AND (name LIKE ? OR barcode LIKE ?)';
      whereArgs = [categoryId, cleanQuery, cleanQuery];
    } else {
      whereClause = 'name LIKE ? OR barcode LIKE ?';
      whereArgs = [cleanQuery, cleanQuery];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'name ASC',
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<int> insertProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'products',
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> toggleProductStock(String id, bool inStock) async {
    final db = await _dbHelper.database;
    return await db.update(
      'products',
      {'in_stock': inStock ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Stock Adjustment & Waste Logging ---

  /// Adjusts stock for a product, recording who, when, and why in the audit log.
  /// If [absoluteCount] is true, [quantityChange] is treated as the new absolute stock count.
  /// Otherwise, [quantityChange] is added to/deducted from current stock (e.g. +10 or -3).
  Future<int> adjustProductStock({
    required String productId,
    required int quantityChange,
    required String reasonCode,
    String? notes,
    required String userId,
    required String userName,
    required String userRole,
    bool absoluteCount = false,
  }) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final maps = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (maps.isEmpty) return 0;

      final current = Product.fromMap(maps.first);
      final prevStock = current.stockQuantity;
      final int newStock;
      final int actualChange;

      if (absoluteCount) {
        newStock = quantityChange.clamp(0, 999999);
        actualChange = newStock - prevStock;
      } else {
        newStock = (prevStock + quantityChange).clamp(0, 999999);
        actualChange = quantityChange;
      }

      final inStockFlag = newStock > 0 ? 1 : 0;
      await txn.update(
        'products',
        {
          'stock_quantity': newStock,
          'in_stock': inStockFlag,
        },
        where: 'id = ?',
        whereArgs: [productId],
      );

      final auditLog = StockAuditLog(
        id: 'stk_${DateTime.now().microsecondsSinceEpoch}',
        productId: productId,
        productName: current.name,
        changeQty: actualChange,
        previousStock: prevStock,
        newStock: newStock,
        reasonCode: reasonCode,
        notes: notes,
        userId: userId,
        userName: userName,
        userRole: userRole,
        createdAt: DateTime.now(),
      );

      await txn.insert(
        'stock_audit_logs',
        auditLog.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return newStock;
    });
  }

  /// Automatically deducts sold item quantities upon order checkout
  Future<void> deductStockForOrderItems({
    required List<OrderItemModel> items,
    required String orderId,
    required String receiptNo,
    required String userId,
    required String userName,
    required String userRole,
  }) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final item in items) {
        final maps = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [item.productId],
          limit: 1,
        );
        if (maps.isNotEmpty) {
          final current = Product.fromMap(maps.first);
          final prevStock = current.stockQuantity;
          final newStock = (prevStock - item.quantity).clamp(0, 999999);
          final inStockFlag = newStock > 0 ? 1 : 0;

          await txn.update(
            'products',
            {
              'stock_quantity': newStock,
              'in_stock': inStockFlag,
            },
            where: 'id = ?',
            whereArgs: [item.productId],
          );

          final auditLog = StockAuditLog(
            id: 'stk_sale_${DateTime.now().microsecondsSinceEpoch}_${item.productId}',
            productId: item.productId,
            productName: item.productName,
            changeQty: -item.quantity,
            previousStock: prevStock,
            newStock: newStock,
            reasonCode: 'sale_deduction',
            notes: 'Auto-deducted from Order #$receiptNo (Qty: ${item.quantity})',
            userId: userId,
            userName: userName,
            userRole: userRole,
            createdAt: DateTime.now(),
          );

          await txn.insert(
            'stock_audit_logs',
            auditLog.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  /// Retrieves audit logs, ordered from newest to oldest
  Future<List<StockAuditLog>> getStockAuditLogs({
    String? productId,
    String? reasonCode,
    bool wasteOnly = false,
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;
    String? whereClause;
    List<dynamic>? whereArgs;

    final conditions = <String>[];
    final args = <dynamic>[];

    if (productId != null && productId.isNotEmpty) {
      conditions.add('product_id = ?');
      args.add(productId);
    }

    if (wasteOnly) {
      conditions.add("reason_code IN ('damaged', 'expired', 'waste')");
    } else if (reasonCode != null && reasonCode.isNotEmpty && reasonCode != 'ALL') {
      conditions.add('reason_code = ?');
      args.add(reasonCode);
    }

    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
      whereArgs = args;
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'stock_audit_logs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return maps.map((m) => StockAuditLog.fromMap(m)).toList();
  }
}
