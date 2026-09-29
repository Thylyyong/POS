class StockAuditLog {
  final String id;
  final String productId;
  final String productName;
  final int changeQty; // e.g. +20, -3
  final int previousStock;
  final int newStock;
  final String reasonCode; // vendor_delivery, recount, damaged, expired, waste, sale_deduction, other
  final String? notes;
  final String userId;
  final String userName;
  final String userRole;
  final DateTime createdAt;

  StockAuditLog({
    required this.id,
    required this.productId,
    required this.productName,
    required this.changeQty,
    required this.previousStock,
    required this.newStock,
    required this.reasonCode,
    this.notes,
    required this.userId,
    required this.userName,
    required this.userRole,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get reasonDisplayName {
    switch (reasonCode.toLowerCase()) {
      case 'vendor_delivery':
        return 'Vendor Delivery / Restock';
      case 'recount':
        return 'Inventory Recount';
      case 'damaged':
        return 'Damaged Goods';
      case 'expired':
        return 'Expired Item';
      case 'waste':
        return 'Kitchen / Prep Waste';
      case 'sale_deduction':
        return 'POS Sale Checkout';
      case 'other':
      default:
        return 'Manual Adjustment';
    }
  }

  bool get isWasteOrLoss =>
      reasonCode.toLowerCase() == 'damaged' ||
      reasonCode.toLowerCase() == 'expired' ||
      reasonCode.toLowerCase() == 'waste';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'change_qty': changeQty,
      'previous_stock': previousStock,
      'new_stock': newStock,
      'reason_code': reasonCode,
      'notes': notes,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StockAuditLog.fromMap(Map<String, dynamic> map) {
    return StockAuditLog(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      changeQty: (map['change_qty'] as num).toInt(),
      previousStock: (map['previous_stock'] as num).toInt(),
      newStock: (map['new_stock'] as num).toInt(),
      reasonCode: map['reason_code'] as String,
      notes: map['notes'] as String?,
      userId: map['user_id'] as String,
      userName: map['user_name'] as String,
      userRole: map['user_role'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
