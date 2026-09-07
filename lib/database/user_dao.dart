import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import 'db_helper.dart';

class UserDao {
  final DbHelper _dbHelper = DbHelper();

  /// Retrieve all registered employees/users
  Future<List<UserModel>> getAllUsers() async {
    final db = await _dbHelper.database;
    final results = await db.query('users', orderBy: 'id ASC');
    return results.map((row) => UserModel.fromMap(row)).toList();
  }

  /// Find user by PIN code
  Future<UserModel?> getUserByPin(String pin) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'users',
      where: 'pin_code = ?',
      whereArgs: [pin.trim()],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return UserModel.fromMap(results.first);
  }

  /// Find user by ID
  Future<UserModel?> getUserById(String id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return UserModel.fromMap(results.first);
  }

  /// Insert or replace user
  Future<void> saveUser(UserModel user) async {
    final db = await _dbHelper.database;
    await db.insert(
      'users',
      user.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update user PIN code
  Future<int> updateUserPin(String userId, String newPin) async {
    final db = await _dbHelper.database;
    return await db.update(
      'users',
      {'pin_code': newPin.trim()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Delete user
  Future<int> deleteUser(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
