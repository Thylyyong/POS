import 'package:sqflite/sqflite.dart';

import '../models/accounting_model.dart';
import 'db_helper.dart';

class AccountingDao {
  final DbHelper _dbHelper = DbHelper();

  /// Log an operating expense
  Future<ExpenseEntryModel> addExpense({
    required String branchId,
    required String category,
    required String title,
    required double amount,
    String? notes,
    required String loggedByUserId,
    String? loggedByUserName,
  }) async {
    final db = await _dbHelper.database;
    final id = 'exp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final expense = ExpenseEntryModel(
      id: id,
      branchId: branchId,
      category: category,
      title: title,
      amount: amount,
      notes: notes,
      loggedByUserId: loggedByUserId,
      loggedByUserName: loggedByUserName,
      createdAt: now,
    );

    await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return expense;
  }

  /// Get expenses for a specific branch and date range
  Future<List<ExpenseEntryModel>> getExpenses({
    String? branchId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (branchId != null && branchId.isNotEmpty && branchId != 'all') {
      whereClauses.add('branch_id = ?');
      whereArgs.add(branchId);
    }

    if (startDate != null) {
      whereClauses.add('created_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      whereClauses.add('created_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final whereStr = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;

    final maps = await db.query(
      'expenses',
      where: whereStr,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
    );

    return maps.map((m) => ExpenseEntryModel.fromMap(m)).toList();
  }

  /// Get Hybrid Settlement Config for a branch
  Future<HybridSettlementConfigModel> getHybridConfig(String branchId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'hybrid_settlement_configs',
      where: 'branch_id = ?',
      whereArgs: [branchId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return HybridSettlementConfigModel.fromMap(maps.first);
    }

    // Default fallback config
    return HybridSettlementConfigModel(
      id: 'config_$branchId',
      branchId: branchId,
      baseRentAmount: 500.0,
      royaltyPercent: 3.0,
    );
  }

  /// Save / Update Hybrid Settlement Config
  Future<void> saveHybridConfig(HybridSettlementConfigModel config) async {
    final db = await _dbHelper.database;
    await db.insert(
      'hybrid_settlement_configs',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Compute full Odoo-style Profit & Loss Report
  Future<ProfitLossReportModel> computeProfitLoss({
    required String branchId, // 'store_a', 'store_b', or 'all'
    required DateTime startDate,
    required DateTime endDate,
    required String periodLabel,
  }) async {
    final db = await _dbHelper.database;
    final isConsolidated = branchId == 'all' || branchId.isEmpty;

    final startStr = startDate.toIso8601String();
    final endStr = endDate.toIso8601String();

    // 1. Query Orders & Revenue
    String orderWhere = 'created_at >= ? AND created_at <= ? AND status = ?';
    List<dynamic> orderArgs = [startStr, endStr, 'COMPLETED'];

    if (!isConsolidated) {
      orderWhere += ' AND branch_id = ?';
      orderArgs.add(branchId);
    }

    final orders = await db.query(
      'orders',
      where: orderWhere,
      whereArgs: orderArgs,
    );

    double grossSales = 0.0;
    for (var ord in orders) {
      grossSales += (ord['total_amount'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Query Order Items for Cost of Goods Sold (COGS)
    // If order items don't have cost, join with products table
    double totalCogs = 0.0;
    final orderIds = orders.map((o) => o['id']).toList();

    if (orderIds.isNotEmpty) {
      final placeholders = List.filled(orderIds.length, '?').join(',');
      final itemsQuery = await db.rawQuery('''
        SELECT oi.quantity, p.cost, oi.unit_price
        FROM order_items oi
        LEFT JOIN products p ON oi.product_id = p.id
        WHERE oi.order_id IN ($placeholders)
      ''', orderIds);

      for (var row in itemsQuery) {
        final qty = (row['quantity'] as num?)?.toInt() ?? 1;
        final cost =
            (row['cost'] as num?)?.toDouble() ??
            ((row['unit_price'] as num?)?.toDouble() ?? 0.0) * 0.40;
        totalCogs += cost * qty;
      }
    }

    // 3. Query Operating Expenses
    final expenses = await getExpenses(
      branchId: isConsolidated ? null : branchId,
      startDate: startDate,
      endDate: endDate,
    );

    double totalExpenses = 0.0;
    for (var exp in expenses) {
      totalExpenses += exp.amount;
    }

    // 4. Calculate Hybrid Settlements
    double baseRentPaid = 0.0;
    double royaltyPaid = 0.0;
    double totalRentCollected = 0.0;
    double totalRoyaltiesCollected = 0.0;

    if (!isConsolidated) {
      final config = await getHybridConfig(branchId);
      baseRentPaid = config.baseRentAmount;
      royaltyPaid = grossSales * (config.royaltyPercent / 100.0);
    } else {
      // For consolidated (Main Boss): sum payouts across store_a and store_b
      final configA = await getHybridConfig('store_a');
      final configB = await getHybridConfig('store_b');

      final ordersA = await db.query(
        'orders',
        where: 'created_at >= ? AND created_at <= ? AND status = ? AND branch_id = ?',
        whereArgs: [startStr, endStr, 'COMPLETED', 'store_a'],
      );
      final ordersB = await db.query(
        'orders',
        where: 'created_at >= ? AND created_at <= ? AND status = ? AND branch_id = ?',
        whereArgs: [startStr, endStr, 'COMPLETED', 'store_b'],
      );

      double salesA = ordersA.fold(
        0.0,
        (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0.0),
      );
      double salesB = ordersB.fold(
        0.0,
        (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0.0),
      );

      totalRentCollected = configA.baseRentAmount + configB.baseRentAmount;
      totalRoyaltiesCollected =
          (salesA * (configA.royaltyPercent / 100.0)) +
          (salesB * (configB.royaltyPercent / 100.0));
    }

    String branchName = isConsolidated
        ? 'Consolidated Enterprise (All Stores)'
        : (branchId == 'store_a'
              ? 'Store Branch A (Downtown)'
              : 'Store Branch B (Uptown)');

    return ProfitLossReportModel(
      periodLabel: periodLabel,
      branchId: branchId,
      branchName: branchName,
      isConsolidated: isConsolidated,
      grossSalesRevenue: grossSales,
      costOfSales: totalCogs,
      operatingExpenses: totalExpenses,
      baseRentPaidToMainBoss: baseRentPaid,
      salesRoyaltyPaidToMainBoss: royaltyPaid,
      otherIncome: isConsolidated ? 0.0 : 150.0, // e.g. vendor rebates
      otherExpenses: isConsolidated ? 0.0 : 50.0, // bank card fees
      totalRentCollected: totalRentCollected,
      totalRoyaltiesCollected: totalRoyaltiesCollected,
    );
  }
}
