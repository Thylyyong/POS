import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/order_model.dart';
import 'db_helper.dart';

class SalesMetrics {
  final double totalRevenue;
  final double totalCost;
  final double grossProfit;
  final int totalOrders;
  final int totalItemsSold;
  final double averageOrderValue;
  final double cashRevenue;
  final double qrRevenue;
  final int cashOrderCount;
  final int qrOrderCount;

  SalesMetrics({
    required this.totalRevenue,
    required this.totalCost,
    required this.grossProfit,
    required this.totalOrders,
    required this.totalItemsSold,
    required this.averageOrderValue,
    required this.cashRevenue,
    required this.qrRevenue,
    required this.cashOrderCount,
    required this.qrOrderCount,
  });
}

class TopSellingItem {
  final String productId;
  final String productName;
  final int totalQuantity;
  final double totalRevenue;

  TopSellingItem({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}

class OrderDao {
  final DbHelper _dbHelper = DbHelper();

  // Generate Unique Receipt Number: REC-YYYYMMDD-XXXX
  Future<String> generateNextReceiptNumber() async {
    final db = await _dbHelper.database;
    final todayStr = DateFormat('yyyyMMdd').format(DateTime.now());
    final prefix = 'REC-$todayStr-';

    final result = await db.rawQuery(
      'SELECT receipt_no FROM orders WHERE receipt_no LIKE ? ORDER BY receipt_no DESC LIMIT 1',
      ['$prefix%'],
    );

    if (result.isNotEmpty) {
      final lastNo = result.first['receipt_no'] as String;
      final seqStr = lastNo.replaceFirst(prefix, '');
      final seq = int.tryParse(seqStr) ?? 0;
      final nextSeq = (seq + 1).toString().padLeft(4, '0');
      return '$prefix$nextSeq';
    } else {
      return '${prefix}0001';
    }
  }

  // Generate Sequential Daily Order Number: 0001, 0002, 0003...
  Future<String> generateNextDailyOrderNumber() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM orders WHERE created_at >= ?',
      [todayStart],
    );

    final count = (result.first['count'] as int?) ?? 0;
    final nextNum = count + 1;
    return nextNum.toString().padLeft(4, '0');
  }

  // Save Pending Order (For Tables / Dine-in without immediate payment)
  Future<OrderModel> savePendingOrder({
    required OrderModel order,
    required List<OrderItemModel> items,
  }) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      await txn.insert('orders', order.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      for (var item in items) {
        final itemMap = item.toMap()..['order_id'] = order.id;
        await txn.insert('order_items', itemMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      if (order.tableId != null && order.tableId!.isNotEmpty) {
        await txn.update(
          'dining_tables',
          {
            'status': 'OCCUPIED',
            'current_order_id': order.id,
            'customer_name': order.customerName,
            'order_total': order.totalAmount,
          },
          where: 'id = ?',
          whereArgs: [order.tableId],
        );
      }

      return order.copyWith(items: items);
    });
  }

  // Atomically Save Full Completed Order Transaction
  Future<OrderModel> saveOrderTransaction({
    required OrderModel order,
    required List<OrderItemModel> items,
    required String action,
    String? receiptFilePath,
  }) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      // 1. Insert/Update Order
      await txn.insert('orders', order.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Insert Order Items
      for (var item in items) {
        final itemMap = item.toMap()..['order_id'] = order.id;
        await txn.insert('order_items', itemMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 3. Free Table if assigned
      if (order.tableId != null && order.tableId!.isNotEmpty) {
        await txn.update(
          'dining_tables',
          {
            'status': 'AVAILABLE',
            'current_order_id': null,
            'customer_name': null,
            'order_total': null,
          },
          where: 'id = ?',
          whereArgs: [order.tableId],
        );
      }

      // 4. Insert Initial Receipt Log
      final log = ReceiptLogModel(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        receiptNo: order.receiptNo,
        orderId: order.id,
        action: action,
        timestamp: DateTime.now(),
        isSuccess: true,
        receiptFilePath: receiptFilePath,
      );
      await txn.insert('receipt_logs', log.toMap());

      return order.copyWith(items: items);
    });
  }

  // Complete a previously pending order
  Future<OrderModel> completePendingOrder({
    required String orderId,
    required PaymentMethod paymentMethod,
    required double cashTendered,
    required double changeAmount,
    String? receiptFilePath,
  }) async {
    final order = await getOrderById(orderId);
    if (order == null) throw Exception('Order not found: $orderId');

    final updatedOrder = order.copyWith(
      status: OrderStatus.completed,
      paymentMethod: paymentMethod,
      cashTendered: cashTendered,
      changeAmount: changeAmount,
    );

    return await saveOrderTransaction(
      order: updatedOrder,
      items: order.items,
      action: 'PAYMENT_COMPLETED',
      receiptFilePath: receiptFilePath,
    );
  }

  // Get Pending Orders
  Future<List<OrderModel>> getPendingOrders() async {
    final db = await _dbHelper.database;
    final orderMaps = await db.query(
      'orders',
      where: "status = 'PENDING'",
      orderBy: 'created_at DESC',
    );

    final orders = <OrderModel>[];
    for (var m in orderMaps) {
      final orderId = m['id'] as String;
      final itemMaps = await db.query('order_items', where: 'order_id = ?', whereArgs: [orderId]);
      final items = itemMaps.map((im) => OrderItemModel.fromMap(im)).toList();
      orders.add(OrderModel.fromMap(m, items: items));
    }
    return orders;
  }

  // Log Receipt Action
  Future<void> logReceiptAction({
    required String receiptNo,
    required String orderId,
    required String action,
    bool isSuccess = true,
    String? errorMessage,
    String? receiptFilePath,
  }) async {
    final db = await _dbHelper.database;
    final log = ReceiptLogModel(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      receiptNo: receiptNo,
      orderId: orderId,
      action: action,
      timestamp: DateTime.now(),
      isSuccess: isSuccess,
      errorMessage: errorMessage,
      receiptFilePath: receiptFilePath,
    );
    await db.insert('receipt_logs', log.toMap());
  }

  // Get Order by ID with Items
  Future<OrderModel?> getOrderById(String orderId) async {
    final db = await _dbHelper.database;
    final orderMaps = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );

    if (orderMaps.isEmpty) return null;

    final itemMaps = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );

    final items = itemMaps.map((m) => OrderItemModel.fromMap(m)).toList();
    return OrderModel.fromMap(orderMaps.first, items: items);
  }

  // Get Order by Receipt Number
  Future<OrderModel?> getOrderByReceiptNo(String receiptNo) async {
    final db = await _dbHelper.database;
    final orderMaps = await db.query(
      'orders',
      where: 'receipt_no = ?',
      whereArgs: [receiptNo],
      limit: 1,
    );

    if (orderMaps.isEmpty) return null;

    final orderId = orderMaps.first['id'] as String;
    final itemMaps = await db.query(
      'order_items',
      where: 'order_id = ?',
      whereArgs: [orderId],
    );

    final items = itemMaps.map((m) => OrderItemModel.fromMap(m)).toList();
    return OrderModel.fromMap(orderMaps.first, items: items);
  }

  // Fetch Order History with Filters
  Future<List<OrderModel>> getOrders({
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    int limit = 100,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('created_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('created_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(receipt_no LIKE ? OR payment_method LIKE ? OR customer_name LIKE ? OR table_number LIKE ?)');
      whereArgs.add('%${searchQuery.trim()}%');
      whereArgs.add('%${searchQuery.trim()}%');
      whereArgs.add('%${searchQuery.trim()}%');
      whereArgs.add('%${searchQuery.trim()}%');
    }

    final whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

    final orderMaps = await db.query(
      'orders',
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final orders = <OrderModel>[];
    for (var m in orderMaps) {
      final orderId = m['id'] as String;
      final itemMaps = await db.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
      final items = itemMaps.map((im) => OrderItemModel.fromMap(im)).toList();
      orders.add(OrderModel.fromMap(m, items: items));
    }
    return orders;
  }

  // Fetch Receipt Logs for Auditing
  Future<List<ReceiptLogModel>> getReceiptLogs({int limit = 100}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'receipt_logs',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return maps.map((m) => ReceiptLogModel.fromMap(m)).toList();
  }

  // Analytics Metrics Calculation for Dashboard
  Future<SalesMetrics> getSalesMetrics({DateTime? startDate, DateTime? endDate}) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>["status = 'COMPLETED'"];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('created_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('created_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final whereString = whereClauses.join(' AND ');

    // Order Totals Query
    final orderSummary = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_orders,
        COALESCE(SUM(total_amount), 0.0) as total_revenue,
        COALESCE(SUM(CASE WHEN payment_method = 'CASH' THEN total_amount ELSE 0.0 END), 0.0) as cash_revenue,
        COALESCE(SUM(CASE WHEN payment_method LIKE '%QR%' THEN total_amount ELSE 0.0 END), 0.0) as qr_revenue,
        COALESCE(SUM(CASE WHEN payment_method = 'CASH' THEN 1 ELSE 0 END), 0) as cash_orders,
        COALESCE(SUM(CASE WHEN payment_method LIKE '%QR%' THEN 1 ELSE 0 END), 0) as qr_orders
      FROM orders
      WHERE $whereString
    ''', whereArgs);

    final totalOrders = (orderSummary.first['total_orders'] as int?) ?? 0;
    final totalRevenue = (orderSummary.first['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final cashRevenue = (orderSummary.first['cash_revenue'] as num?)?.toDouble() ?? 0.0;
    final qrRevenue = (orderSummary.first['qr_revenue'] as num?)?.toDouble() ?? 0.0;
    final cashOrders = (orderSummary.first['cash_orders'] as int?) ?? 0;
    final qrOrders = (orderSummary.first['qr_orders'] as int?) ?? 0;

    // Items and Cost Calculation with explicit aliasing
    final itemWhereClauses = <String>["o.status = 'COMPLETED'"];
    final itemWhereArgs = <dynamic>[];

    if (startDate != null) {
      itemWhereClauses.add('o.created_at >= ?');
      itemWhereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      itemWhereClauses.add('o.created_at <= ?');
      itemWhereArgs.add(endDate.toIso8601String());
    }

    final itemWhereString = itemWhereClauses.join(' AND ');

    final itemSummary = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(oi.quantity), 0) as total_items,
        COALESCE(SUM(oi.quantity * COALESCE(p.cost, 0.0)), 0.0) as total_cost
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      LEFT JOIN products p ON oi.product_id = p.id
      WHERE $itemWhereString
    ''', itemWhereArgs);

    final totalItemsSold = (itemSummary.first['total_items'] as int?) ?? 0;
    final totalCost = (itemSummary.first['total_cost'] as num?)?.toDouble() ?? 0.0;
    final grossProfit = totalRevenue - totalCost;
    final averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    return SalesMetrics(
      totalRevenue: totalRevenue,
      totalCost: totalCost,
      grossProfit: grossProfit,
      totalOrders: totalOrders,
      totalItemsSold: totalItemsSold,
      averageOrderValue: averageOrderValue,
      cashRevenue: cashRevenue,
      qrRevenue: qrRevenue,
      cashOrderCount: cashOrders,
      qrOrderCount: qrOrders,
    );
  }

  // Top Selling Items by Quantity & Revenue
  Future<List<TopSellingItem>> getTopSellingItems({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 10,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>["o.status = 'COMPLETED'"];
    final whereArgs = <dynamic>[];

    if (startDate != null) {
      whereClauses.add('o.created_at >= ?');
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClauses.add('o.created_at <= ?');
      whereArgs.add(endDate.toIso8601String());
    }

    final whereString = whereClauses.join(' AND ');

    final results = await db.rawQuery('''
      SELECT 
        oi.product_id,
        oi.product_name,
        SUM(oi.quantity) as total_qty,
        SUM(oi.total_price) as total_rev
      FROM order_items oi
      JOIN orders o ON oi.order_id = o.id
      WHERE $whereString
      GROUP BY oi.product_id, oi.product_name
      ORDER BY total_qty DESC, total_rev DESC
      LIMIT $limit
    ''', whereArgs);

    return results.map((r) => TopSellingItem(
      productId: r['product_id'] as String,
      productName: r['product_name'] as String,
      totalQuantity: (r['total_qty'] as num?)?.toInt() ?? 0,
      totalRevenue: (r['total_rev'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }
}
