class ExpenseEntryModel {
  final String id;
  final String branchId;
  final String category; // 'OPERATING', 'RENT', 'UTILITIES', 'SUPPLIES', 'SALARIES', 'OTHER'
  final String title;
  final double amount;
  final String? notes;
  final String loggedByUserId;
  final String? loggedByUserName;
  final DateTime createdAt;

  ExpenseEntryModel({
    required this.id,
    required this.branchId,
    required this.category,
    required this.title,
    required this.amount,
    this.notes,
    required this.loggedByUserId,
    this.loggedByUserName,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'category': category,
      'title': title,
      'amount': amount,
      'notes': notes,
      'logged_by_user_id': loggedByUserId,
      'logged_by_user_name': loggedByUserName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ExpenseEntryModel.fromMap(Map<String, dynamic> map) {
    return ExpenseEntryModel(
      id: map['id'] as String,
      branchId: map['branch_id'] as String,
      category: map['category'] as String? ?? 'OPERATING',
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      notes: map['notes'] as String?,
      loggedByUserId: map['logged_by_user_id'] as String,
      loggedByUserName: map['logged_by_user_name'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class HybridSettlementConfigModel {
  final String id;
  final String branchId;
  final double baseRentAmount;
  final double royaltyPercent;
  final String settlementCycle; // 'MONTHLY', 'DAILY'

  const HybridSettlementConfigModel({
    required this.id,
    required this.branchId,
    this.baseRentAmount = 500.0,
    this.royaltyPercent = 3.0,
    this.settlementCycle = 'MONTHLY',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'base_rent_amount': baseRentAmount,
      'royalty_percent': royaltyPercent,
      'settlement_cycle': settlementCycle,
    };
  }

  factory HybridSettlementConfigModel.fromMap(Map<String, dynamic> map) {
    return HybridSettlementConfigModel(
      id: map['id'] as String,
      branchId: map['branch_id'] as String,
      baseRentAmount: (map['base_rent_amount'] as num?)?.toDouble() ?? 500.0,
      royaltyPercent: (map['royalty_percent'] as num?)?.toDouble() ?? 3.0,
      settlementCycle: map['settlement_cycle'] as String? ?? 'MONTHLY',
    );
  }
}

class ProfitLossReportModel {
  final String periodLabel; // e.g. "2026" or "September 2026"
  final String branchId;
  final String branchName;
  final bool isConsolidated;

  // 1. Income Section
  final double grossSalesRevenue;
  final double costOfSales; // COGS

  // 2. Expense Section
  final double operatingExpenses; // local wages, utilities, supplies
  final double baseRentPaidToMainBoss; // Hybrid fixed rent
  final double salesRoyaltyPaidToMainBoss; // Hybrid variable % royalty
  final double otherExpenses;

  // 3. Other Income
  final double otherIncome;

  // For Main Boss Consolidated View
  final double totalRentCollected;
  final double totalRoyaltiesCollected;

  ProfitLossReportModel({
    required this.periodLabel,
    required this.branchId,
    required this.branchName,
    this.isConsolidated = false,
    required this.grossSalesRevenue,
    required this.costOfSales,
    required this.operatingExpenses,
    this.baseRentPaidToMainBoss = 0.0,
    this.salesRoyaltyPaidToMainBoss = 0.0,
    this.otherExpenses = 0.0,
    this.otherIncome = 0.0,
    this.totalRentCollected = 0.0,
    this.totalRoyaltiesCollected = 0.0,
  });

  // Odoo P&L Calculated Fields
  double get grossProfit => grossSalesRevenue - costOfSales;

  double get totalHybridSettlementToMainBoss =>
      baseRentPaidToMainBoss + salesRoyaltyPaidToMainBoss;

  double get totalDirectExpenses =>
      operatingExpenses + totalHybridSettlementToMainBoss;

  double get netOperatingIncome => grossProfit - totalDirectExpenses;

  double get netOtherIncome => otherIncome - otherExpenses;

  double get netIncome => netOperatingIncome + netOtherIncome;

  // Main Boss Executive Earnings
  double get mainBossGrossInflow =>
      totalRentCollected + totalRoyaltiesCollected + (isConsolidated ? 0 : 0);

  double get mainBossNetInflow => mainBossGrossInflow - operatingExpenses;
}
