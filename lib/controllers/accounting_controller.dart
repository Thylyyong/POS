import 'package:flutter/material.dart';

import '../database/accounting_dao.dart';
import '../models/accounting_model.dart';
import '../models/store_settings_model.dart';
import '../services/excel_export_service.dart';

class AccountingController extends ChangeNotifier {
  final AccountingDao _dao = AccountingDao();

  ProfitLossReportModel? _report;
  ProfitLossReportModel? get report => _report;

  List<ProfitLossReportModel> _visibleReports = [];
  List<ProfitLossReportModel> get visibleReports => _visibleReports;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  List<ExpenseEntryModel> _expenses = [];
  List<ExpenseEntryModel> get expenses => _expenses;

  HybridSettlementConfigModel? _hybridConfig;
  HybridSettlementConfigModel? get hybridConfig => _hybridConfig;

  String _selectedPeriod = '2026';
  String get selectedPeriod => _selectedPeriod;

  String _selectedBranch = 'all';
  String get selectedBranch => _selectedBranch;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// Load P&L report for specific branch and period
  Future<void> loadReport({
    String? branchId,
    String? period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    if (branchId != null) _selectedBranch = branchId;
    if (period != null) _selectedPeriod = period;

    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, 1, 1);
    final end = endDate ?? DateTime(now.year, 12, 31, 23, 59, 59);

    try {
      _report = await _dao.computeProfitLoss(
        branchId: _selectedBranch,
        startDate: start,
        endDate: end,
        periodLabel: _selectedPeriod,
      );

      _report = await _dao.computeProfitLoss(
        branchId: _selectedBranch,
        startDate: start,
        endDate: end,
        periodLabel: _selectedPeriod,
      );

      _visibleReports = _report != null ? [_report!] : [];

      _expenses = await _dao.getExpenses(
        branchId: _selectedBranch == 'all' ? null : _selectedBranch,
        startDate: start,
        endDate: end,
      );

      _hybridConfig = null;
    } catch (e) {
      _error = 'Failed to load accounting report: $e';
      debugPrint('[AccountingController] $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> exportVisibleReports(StoreSettingsModel settings) async {
    if (_visibleReports.isEmpty) return null;
    _isExporting = true;
    notifyListeners();
    try {
      return await ExcelExportService().exportProfitLossReports(
        reports: _visibleReports,
        settings: settings,
        periodLabel: _selectedPeriod,
      );
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Log a new operating expense
  Future<ExpenseEntryModel> addExpense({
    required String branchId,
    required String category,
    required String title,
    required double amount,
    String? notes,
    required String loggedByUserId,
    String? loggedByUserName,
  }) async {
    final expense = await _dao.addExpense(
      branchId: branchId,
      category: category,
      title: title,
      amount: amount,
      notes: notes,
      loggedByUserId: loggedByUserId,
      loggedByUserName: loggedByUserName,
    );

    await loadReport(branchId: _selectedBranch, period: _selectedPeriod);
    return expense;
  }

  /// Delete an operating expense
  Future<void> deleteExpense(String id) async {
    await _dao.deleteExpense(id);
    await loadReport(branchId: _selectedBranch, period: _selectedPeriod);
  }

  // ── Expense Categories Management ──────────────────────────────────────────

  List<String> _expenseCategories = [
    'General Operating',
    'Staff Wages / Payroll',
    'Electricity & Water',
    'Store Supplies & Paper',
    'Facility Rent',
  ];
  List<String> get expenseCategories => _expenseCategories;

  Future<void> loadExpenseCategories() async {
    _expenseCategories = await _dao.getExpenseCategories();
    notifyListeners();
  }

  Future<void> addExpenseCategory(String category) async {
    final trimmed = category.trim();
    if (trimmed.isEmpty || _expenseCategories.contains(trimmed)) return;
    _expenseCategories.add(trimmed);
    await _dao.saveExpenseCategories(_expenseCategories);
    notifyListeners();
  }

  Future<void> deleteExpenseCategory(String category) async {
    _expenseCategories.remove(category);
    if (_expenseCategories.isEmpty) {
      _expenseCategories = ['General Operating'];
    }
    await _dao.saveExpenseCategories(_expenseCategories);
    notifyListeners();
  }

  /// Update Hybrid Franchise Settlement terms
  Future<void> saveHybridConfig(HybridSettlementConfigModel config) async {
    await _dao.saveHybridConfig(config);
    _hybridConfig = config;
    await loadReport(branchId: _selectedBranch, period: _selectedPeriod);
  }
}
