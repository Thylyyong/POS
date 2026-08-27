import 'package:sqflite/sqflite.dart';
import '../models/dining_table_model.dart';
import 'db_helper.dart';

class TableDao {
  final DbHelper _dbHelper = DbHelper();

  Future<List<DiningTableModel>> getTables() async {
    final db = await _dbHelper.database;
    final maps = await db.query('dining_tables', orderBy: 'table_number ASC');
    return maps.map((m) => DiningTableModel.fromMap(m)).toList();
  }

  Future<DiningTableModel?> getTableById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'dining_tables',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DiningTableModel.fromMap(maps.first);
  }

  Future<void> insertTable(DiningTableModel table) async {
    final db = await _dbHelper.database;
    await db.insert(
      'dining_tables',
      table.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTable(DiningTableModel table) async {
    final db = await _dbHelper.database;
    await db.update(
      'dining_tables',
      table.toMap(),
      where: 'id = ?',
      whereArgs: [table.id],
    );
  }

  Future<void> deleteTable(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'dining_tables',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> occupyTable({
    required String tableId,
    required String orderId,
    required String customerName,
    required double orderTotal,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'dining_tables',
      {
        'status': TableStatus.occupied.displayName,
        'current_order_id': orderId,
        'customer_name': customerName,
        'order_total': orderTotal,
      },
      where: 'id = ?',
      whereArgs: [tableId],
    );
  }

  Future<void> freeTable(String tableId) async {
    final db = await _dbHelper.database;
    await db.update(
      'dining_tables',
      {
        'status': TableStatus.available.displayName,
        'current_order_id': null,
        'customer_name': null,
        'order_total': null,
      },
      where: 'id = ?',
      whereArgs: [tableId],
    );
  }

  Future<void> setTableStatus(String tableId, TableStatus status) async {
    final db = await _dbHelper.database;
    await db.update(
      'dining_tables',
      {'status': status.displayName},
      where: 'id = ?',
      whereArgs: [tableId],
    );
  }
}
