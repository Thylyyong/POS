enum RegisterStatus {
  open,
  closed,
}

class DenominationItem {
  final double value;
  final String label;
  int count;

  DenominationItem({
    required this.value,
    required this.label,
    this.count = 0,
  });

  double get total => value * count;
}

class RegisterSessionModel {
  final String id;
  final String branchId;
  final String branchName;
  final String cashierId;
  final String cashierName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final double openingCash;
  final String? openingNotes;

  final double closingCashCounted;
  final double closingCardCounted;
  final double closingCustomerAccountCounted;
  final double expectedCash;
  final double cashDifference; // counted - expected
  final String? closingNotes;
  final RegisterStatus status;

  final int totalOrders;
  final double totalCashSales;
  final double totalCardSales;
  final double totalQrSales;
  final double totalCashIn;
  final double totalCashOut;

  RegisterSessionModel({
    required this.id,
    required this.branchId,
    required this.branchName,
    required this.cashierId,
    required this.cashierName,
    required this.openedAt,
    this.closedAt,
    required this.openingCash,
    this.openingNotes,
    this.closingCashCounted = 0.0,
    this.closingCardCounted = 0.0,
    this.closingCustomerAccountCounted = 0.0,
    this.expectedCash = 0.0,
    this.cashDifference = 0.0,
    this.closingNotes,
    this.status = RegisterStatus.open,
    this.totalOrders = 0,
    this.totalCashSales = 0.0,
    this.totalCardSales = 0.0,
    this.totalQrSales = 0.0,
    this.totalCashIn = 0.0,
    this.totalCashOut = 0.0,
  });

  bool get isOpen => status == RegisterStatus.open;
  bool get isClosed => status == RegisterStatus.closed;

  double get calculatedExpectedCash =>
      openingCash + totalCashSales + totalCashIn - totalCashOut;

  double get calculatedCashDifference =>
      closingCashCounted - calculatedExpectedCash;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'branch_name': branchName,
      'cashier_id': cashierId,
      'cashier_name': cashierName,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'opening_cash': openingCash,
      'opening_notes': openingNotes,
      'closing_cash_counted': closingCashCounted,
      'closing_card_counted': closingCardCounted,
      'closing_customer_account_counted': closingCustomerAccountCounted,
      'expected_cash': expectedCash,
      'cash_difference': cashDifference,
      'closing_notes': closingNotes,
      'status': status.name.toUpperCase(),
      'total_orders': totalOrders,
      'total_cash_sales': totalCashSales,
      'total_card_sales': totalCardSales,
      'total_qr_sales': totalQrSales,
      'total_cash_in': totalCashIn,
      'total_cash_out': totalCashOut,
    };
  }

  factory RegisterSessionModel.fromMap(Map<String, dynamic> map) {
    return RegisterSessionModel(
      id: map['id'] as String,
      branchId: map['branch_id'] as String? ?? 'store_a',
      branchName: map['branch_name'] as String? ?? 'Store A',
      cashierId: map['cashier_id'] as String? ?? 'cashier_01',
      cashierName: map['cashier_name'] as String? ?? 'Staff Cashier',
      openedAt: map['opened_at'] != null
          ? DateTime.tryParse(map['opened_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      closedAt: map['closed_at'] != null
          ? DateTime.tryParse(map['closed_at'] as String)
          : null,
      openingCash: (map['opening_cash'] as num?)?.toDouble() ?? 0.0,
      openingNotes: map['opening_notes'] as String?,
      closingCashCounted: (map['closing_cash_counted'] as num?)?.toDouble() ?? 0.0,
      closingCardCounted: (map['closing_card_counted'] as num?)?.toDouble() ?? 0.0,
      closingCustomerAccountCounted:
          (map['closing_customer_account_counted'] as num?)?.toDouble() ?? 0.0,
      expectedCash: (map['expected_cash'] as num?)?.toDouble() ?? 0.0,
      cashDifference: (map['cash_difference'] as num?)?.toDouble() ?? 0.0,
      closingNotes: map['closing_notes'] as String?,
      status: (map['status'] as String? ?? '').toUpperCase() == 'CLOSED'
          ? RegisterStatus.closed
          : RegisterStatus.open,
      totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
      totalCashSales: (map['total_cash_sales'] as num?)?.toDouble() ?? 0.0,
      totalCardSales: (map['total_card_sales'] as num?)?.toDouble() ?? 0.0,
      totalQrSales: (map['total_qr_sales'] as num?)?.toDouble() ?? 0.0,
      totalCashIn: (map['total_cash_in'] as num?)?.toDouble() ?? 0.0,
      totalCashOut: (map['total_cash_out'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
