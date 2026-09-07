enum PaymentMethod {
  cash,
  qr,
  card;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'CASH';
      case PaymentMethod.qr:
        return 'QR CODE';
      case PaymentMethod.card:
        return 'CARD';
    }
  }

  static PaymentMethod fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CASH':
        return PaymentMethod.cash;
      case 'QR':
      case 'QR CODE':
        return PaymentMethod.qr;
      case 'CARD':
        return PaymentMethod.card;
      default:
        return PaymentMethod.cash;
    }
  }
}

enum OrderStatus {
  pending,
  completed,
  held,
  cancelled;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.completed:
        return 'COMPLETED';
      case OrderStatus.held:
        return 'HOLD';
      case OrderStatus.cancelled:
        return 'CANCELLED';
    }
  }

  static OrderStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PENDING':
        return OrderStatus.pending;
      case 'COMPLETED':
        return OrderStatus.completed;
      case 'HOLD':
      case 'HELD':
        return OrderStatus.held;
      case 'CANCELLED':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.completed;
    }
  }
}

class OrderItemModel {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? notes;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'notes': notes,
    };
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      unitPrice: (map['unit_price'] as num).toDouble(),
      totalPrice: (map['total_price'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }

  OrderItemModel copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productName,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    String? notes,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      notes: notes ?? this.notes,
    );
  }
}

class OrderModel {
  final String id;
  final String branchId;
  final String receiptNo;
  final String? orderNumber; // Sequential daily order # e.g. "001", "002"
  final String? tableId;
  final String? tableNumber;
  final String? customerName;
  final String orderType; // 'DINE_IN', 'TAKEAWAY', 'DELIVERY'
  final double subtotal;
  final double discountAmount;
  final double discountPercent;
  final double taxAmount;
  final double taxRate;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final double cashTendered;
  final double changeAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    this.branchId = 'store_a',
    required this.receiptNo,
    this.orderNumber,
    this.tableId,
    this.tableNumber,
    this.customerName,
    this.orderType = 'DINE_IN',
    required this.subtotal,
    this.discountAmount = 0.0,
    this.discountPercent = 0.0,
    this.taxAmount = 0.0,
    this.taxRate = 0.0,
    required this.totalAmount,
    required this.paymentMethod,
    this.cashTendered = 0.0,
    this.changeAmount = 0.0,
    this.status = OrderStatus.completed,
    DateTime? createdAt,
    this.items = const [],
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPending => status == OrderStatus.pending;
  bool get isDineIn => orderType == 'DINE_IN';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'receipt_no': receiptNo,
      'order_number': orderNumber,
      'table_id': tableId,
      'table_number': tableNumber,
      'customer_name': customerName,
      'order_type': orderType,
      'subtotal': subtotal,
      'discount_amount': discountAmount,
      'discount_percent': discountPercent,
      'tax_amount': taxAmount,
      'tax_rate': taxRate,
      'total_amount': totalAmount,
      'payment_method': paymentMethod.displayName,
      'cash_tendered': cashTendered,
      'change_amount': changeAmount,
      'status': status.displayName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory OrderModel.fromMap(
    Map<String, dynamic> map, {
    List<OrderItemModel> items = const [],
  }) {
    return OrderModel(
      id: map['id'] as String,
      branchId: map['branch_id'] as String? ?? 'store_a',
      receiptNo: map['receipt_no'] as String,
      orderNumber: map['order_number'] as String?,
      tableId: map['table_id'] as String?,
      tableNumber: map['table_number'] as String?,
      customerName: map['customer_name'] as String?,
      orderType: map['order_type'] as String? ?? 'DINE_IN',
      subtotal: (map['subtotal'] as num).toDouble(),
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (map['discount_percent'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0.0,
      taxRate: (map['tax_rate'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentMethod: PaymentMethod.fromString(
        map['payment_method'] as String? ?? 'CASH',
      ),
      cashTendered: (map['cash_tendered'] as num?)?.toDouble() ?? 0.0,
      changeAmount: (map['change_amount'] as num?)?.toDouble() ?? 0.0,
      status: OrderStatus.fromString(map['status'] as String? ?? 'COMPLETED'),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      items: items,
    );
  }

  OrderModel copyWith({
    String? id,
    String? branchId,
    String? receiptNo,
    String? orderNumber,
    String? tableId,
    String? tableNumber,
    String? customerName,
    String? orderType,
    double? subtotal,
    double? discountAmount,
    double? discountPercent,
    double? taxAmount,
    double? taxRate,
    double? totalAmount,
    PaymentMethod? paymentMethod,
    double? cashTendered,
    double? changeAmount,
    OrderStatus? status,
    DateTime? createdAt,
    List<OrderItemModel>? items,
  }) {
    return OrderModel(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      receiptNo: receiptNo ?? this.receiptNo,
      orderNumber: orderNumber ?? this.orderNumber,
      tableId: tableId ?? this.tableId,
      tableNumber: tableNumber ?? this.tableNumber,
      customerName: customerName ?? this.customerName,
      orderType: orderType ?? this.orderType,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      taxAmount: taxAmount ?? this.taxAmount,
      taxRate: taxRate ?? this.taxRate,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cashTendered: cashTendered ?? this.cashTendered,
      changeAmount: changeAmount ?? this.changeAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}

class ReceiptLogModel {
  final String id;
  final String receiptNo;
  final String orderId;
  final String
  action; // 'INITIAL_PRINT', 'REPRINT', 'DIGITAL_VIEW', 'PDF_EXPORT'
  final DateTime timestamp;
  final bool isSuccess;
  final String? errorMessage;
  final String? receiptFilePath;

  ReceiptLogModel({
    required this.id,
    required this.receiptNo,
    required this.orderId,
    required this.action,
    DateTime? timestamp,
    this.isSuccess = true,
    this.errorMessage,
    this.receiptFilePath,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'receipt_no': receiptNo,
      'order_id': orderId,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'is_success': isSuccess ? 1 : 0,
      'error_message': errorMessage,
      'receipt_file_path': receiptFilePath,
    };
  }

  factory ReceiptLogModel.fromMap(Map<String, dynamic> map) {
    return ReceiptLogModel(
      id: map['id'] as String,
      receiptNo: map['receipt_no'] as String,
      orderId: map['order_id'] as String,
      action: map['action'] as String,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSuccess: (map['is_success'] as int? ?? 1) == 1,
      errorMessage: map['error_message'] as String?,
      receiptFilePath: map['receipt_file_path'] as String?,
    );
  }
}
