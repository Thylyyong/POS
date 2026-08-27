import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
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
}
