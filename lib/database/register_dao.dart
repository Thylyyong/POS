import 'package:sqflite/sqflite.dart';
import '../models/cash_movement_model.dart';
import '../models/register_session_model.dart';
import 'db_helper.dart';

class RegisterDao {
  final DbHelper _dbHelper = DbHelper();

  /// Get the active open session for a specific branch (or any if null)
  Future<RegisterSessionModel?> getActiveSession({String? branchId}) async {
    final db = await _dbHelper.database;
    String whereClause = 'status = "OPEN"';
    List<dynamic> whereArgs = [];

    if (branchId != null && branchId.isNotEmpty) {
      whereClause += ' AND branch_id = ?';
      whereArgs.add(branchId);
    }

    final maps = await db.query(
      'register_sessions',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'opened_at DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return RegisterSessionModel.fromMap(maps.first);
    }
    return null;
  }

  /// Create a new register session (Opening Control)
  Future<RegisterSessionModel> openSession({
    required String branchId,
    required String branchName,
    required String cashierId,
    required String cashierName,
    required double openingCash,
    String? openingNotes,
  }) async {
    final db = await _dbHelper.database;
    final id = 'sess_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final session = RegisterSessionModel(
      id: id,
      branchId: branchId,
      branchName: branchName,
      cashierId: cashierId,
      cashierName: cashierName,
      openedAt: now,
      openingCash: openingCash,
      openingNotes: openingNotes,
      status: RegisterStatus.open,
      expectedCash: openingCash,
    );

    await db.insert(
      'register_sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return session;
  }

  /// Close an active register session (Closing Register)
  Future<bool> closeSession({
    required String sessionId,
    required double closingCashCounted,
    required double closingCardCounted,
    double closingCustomerAccountCounted = 0.0,
    required double expectedCash,
    required double cashDifference,
    String? closingNotes,
    int totalOrders = 0,
    double totalCashSales = 0.0,
    double totalCardSales = 0.0,
    double totalQrSales = 0.0,
    double totalCashIn = 0.0,
    double totalCashOut = 0.0,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final count = await db.update(
      'register_sessions',
      {
        'closed_at': now,
        'closing_cash_counted': closingCashCounted,
        'closing_card_counted': closingCardCounted,
        'closing_customer_account_counted': closingCustomerAccountCounted,
        'expected_cash': expectedCash,
        'cash_difference': cashDifference,
        'closing_notes': closingNotes,
        'status': 'CLOSED',
        'total_orders': totalOrders,
        'total_cash_sales': totalCashSales,
        'total_card_sales': totalCardSales,
        'total_qr_sales': totalQrSales,
        'total_cash_in': totalCashIn,
        'total_cash_out': totalCashOut,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );

    return count > 0;
  }

  /// Add a Cash In or Cash Out petty movement
  Future<CashMovementModel> addCashMovement({
    required String sessionId,
    required CashMovementType type,
    required double amount,
    required String reason,
    required String authorizedById,
    String? authorizedByName,
  }) async {
    final db = await _dbHelper.database;
    final id = 'mov_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final movement = CashMovementModel(
      id: id,
      sessionId: sessionId,
      type: type,
      amount: amount,
      reason: reason,
      authorizedById: authorizedById,
      authorizedByName: authorizedByName,
      createdAt: now,
    );

    await db.insert(
      'cash_movements',
      movement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update totals on register session
    if (type == CashMovementType.cashIn) {
      await db.rawUpdate('''
        UPDATE register_sessions 
        SET total_cash_in = total_cash_in + ?, 
            expected_cash = expected_cash + ? 
        WHERE id = ?
      ''', [amount, amount, sessionId]);
    } else {
      await db.rawUpdate('''
        UPDATE register_sessions 
        SET total_cash_out = total_cash_out + ?, 
            expected_cash = expected_cash - ? 
        WHERE id = ?
      ''', [amount, amount, sessionId]);
    }

    return movement;
  }

  /// Get all movements for a session
  Future<List<CashMovementModel>> getSessionMovements(String sessionId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'cash_movements',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => CashMovementModel.fromMap(m)).toList();
  }

  /// Calculate shift sales totals for an active or closed session between opened_at and closed_at/now
  Future<Map<String, dynamic>> calculateShiftSales({
    required DateTime openedAt,
    DateTime? closedAt,
    String? branchId,
  }) async {
    final db = await _dbHelper.database;
    final startStr = openedAt.toIso8601String();
    final endStr = (closedAt ?? DateTime.now()).toIso8601String();

    String where = 'created_at >= ? AND created_at <= ? AND status = "COMPLETED"';
    List<dynamic> args = [startStr, endStr];

    if (branchId != null && branchId.isNotEmpty) {
      where += ' AND branch_id = ?';
      args.add(branchId);
    }

    final orders = await db.query('orders', where: where, whereArgs: args);

    int totalOrders = orders.length;
    double cashSales = 0.0;
    double cardSales = 0.0;
    double qrSales = 0.0;
    double totalRevenue = 0.0;

    for (var ord in orders) {
      final total = (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
      final method = (ord['payment_method'] as String? ?? '').toUpperCase();
      totalRevenue += total;

      if (method.contains('CASH')) {
        cashSales += total;
      } else if (method.contains('CARD')) {
        cardSales += total;
      } else {
        qrSales += total;
      }
    }

    return {
      'total_orders': totalOrders,
      'total_revenue': totalRevenue,
      'total_cash_sales': cashSales,
      'total_card_sales': cardSales,
      'total_qr_sales': qrSales,
    };
  }

  /// List all past register sessions
  Future<List<RegisterSessionModel>> getAllSessions({String? branchId}) async {
    final db = await _dbHelper.database;
    String? where;
    List<dynamic>? args;

    if (branchId != null && branchId.isNotEmpty) {
      where = 'branch_id = ?';
      args = [branchId];
    }

    final maps = await db.query(
      'register_sessions',
      where: where,
      whereArgs: args,
      orderBy: 'opened_at DESC',
    );
    return maps.map((m) => RegisterSessionModel.fromMap(m)).toList();
  }
}

