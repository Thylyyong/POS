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

  /// Get all active (non-locked) users with a specific role
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: [role.displayName],
      orderBy: 'name ASC',
    );
    return results.map((row) => UserModel.fromMap(row)).toList();
  }

  /// Find user by PIN code — returns null if user is locked
  Future<UserModel?> getUserByPin(String pin) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'users',
      where: 'pin_code = ?',
      whereArgs: [pin.trim()],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final user = UserModel.fromMap(results.first);
    // Locked users cannot log in
    if (user.isLocked) return null;
    return user;
  }

  /// Find user by PIN including locked (for admin checks)
  Future<UserModel?> getUserByPinRaw(String pin) async {
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

  /// Update user display name
  Future<int> updateUserName(String userId, String newName) async {
    final db = await _dbHelper.database;
    return await db.update(
      'users',
      {'name': newName.trim()},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Update user role
  Future<int> updateUserRole(String userId, UserRole newRole) async {
    final db = await _dbHelper.database;
    return await db.update(
      'users',
      {'role': newRole.displayName},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Lock a user account — they can no longer log in until unlocked
  Future<int> lockUser(String userId) async {
    final db = await _dbHelper.database;
    return await db.update(
      'users',
      {'is_locked': 1},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Unlock a user account
  Future<int> unlockUser(String userId) async {
    final db = await _dbHelper.database;
    return await db.update(
      'users',
      {'is_locked': 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Toggle lock status
  Future<UserModel?> toggleLock(String userId) async {
    final user = await getUserById(userId);
    if (user == null) return null;
    if (user.isLocked) {
      await unlockUser(userId);
    } else {
      await lockUser(userId);
    }
    return await getUserById(userId);
  }

  /// Check if a PIN already exists (to prevent duplicates)
  Future<bool> isPinTaken(String pin, {String? excludeUserId}) async {
    final db = await _dbHelper.database;
    final where = excludeUserId != null ? 'pin_code = ? AND id != ?' : 'pin_code = ?';
    final args = excludeUserId != null ? [pin.trim(), excludeUserId] : [pin.trim()];
    final results = await db.query('users', where: where, whereArgs: args, limit: 1);
    return results.isNotEmpty;
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
