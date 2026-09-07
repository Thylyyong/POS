enum CashMovementType {
  cashIn,  // Put cash into the drawer
  cashOut, // Take cash out of the drawer (petty expense or safe drop)
}

extension CashMovementTypeExtension on CashMovementType {
  String get displayName {
    switch (this) {
      case CashMovementType.cashIn:
        return 'Cash In';
      case CashMovementType.cashOut:
        return 'Cash Out';
    }
  }
}

class CashMovementModel {
  final String id;
  final String sessionId;
  final CashMovementType type;
  final double amount;
  final String reason;
  final String authorizedById;
  final String? authorizedByName;
  final DateTime createdAt;

  CashMovementModel({
    required this.id,
    required this.sessionId,
    required this.type,
    required this.amount,
    required this.reason,
    required this.authorizedById,
    this.authorizedByName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCashIn => type == CashMovementType.cashIn;
  bool get isCashOut => type == CashMovementType.cashOut;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'type': type.name,
      'amount': amount,
      'reason': reason,
      'authorized_by_id': authorizedById,
      'authorized_by_name': authorizedByName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CashMovementModel.fromMap(Map<String, dynamic> map) {
    return CashMovementModel(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      type: map['type'] == 'cashIn' || map['type'] == 'CASH_IN'
          ? CashMovementType.cashIn
          : CashMovementType.cashOut,
      amount: (map['amount'] as num).toDouble(),
      reason: map['reason'] as String? ?? 'General Adjustment',
      authorizedById: map['authorized_by_id'] as String? ?? 'admin',
      authorizedByName: map['authorized_by_name'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
