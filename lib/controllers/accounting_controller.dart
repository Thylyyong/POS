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

  String _selectedBranch = 'store_a';
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

      final reportBranches = _selectedBranch == 'all'
          ? const ['store_a', 'store_b', 'all']
          : [_selectedBranch];
      _visibleReports = [];
      for (final visibleBranch in reportBranches) {
        _visibleReports.add(
          await _dao.computeProfitLoss(
            branchId: visibleBranch,
            startDate: start,
            endDate: end,
            periodLabel: _selectedPeriod,
          ),
        );
      }

      _expenses = await _dao.getExpenses(
        branchId: _selectedBranch == 'all' ? null : _selectedBranch,
        startDate: start,
        endDate: end,
      );

      if (_selectedBranch != 'all') {
        _hybridConfig = await _dao.getHybridConfig(_selectedBranch);
      } else {
        _hybridConfig = null;
      }
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

  /// Update Hybrid Franchise Settlement terms
  Future<void> saveHybridConfig(HybridSettlementConfigModel config) async {
    await _dao.saveHybridConfig(config);
    _hybridConfig = config;
    await loadReport(branchId: _selectedBranch, period: _selectedPeriod);
  }
}
