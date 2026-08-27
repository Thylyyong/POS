import 'package:flutter/material.dart';
import '../core/async_guard.dart';
import '../database/order_dao.dart';
import '../models/order_model.dart';
import '../models/store_settings_model.dart';
import '../services/excel_export_service.dart';

enum DashboardDateFilter {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  allTime,
  custom;

  String get displayName {
    switch (this) {
      case DashboardDateFilter.today:
        return 'Today';
      case DashboardDateFilter.yesterday:
        return 'Yesterday';
      case DashboardDateFilter.thisWeek:
        return 'This Week';
      case DashboardDateFilter.thisMonth:
        return 'This Month';
      case DashboardDateFilter.allTime:
        return 'All Time';
      case DashboardDateFilter.custom:
        return 'Custom';
    }
  }
}

class DashboardController extends ChangeNotifier {
  final OrderDao _orderDao = OrderDao();
  final ExcelExportService _excelExportService = ExcelExportService();
  final _loadGuard = AsyncGuard();

  DashboardDateFilter _selectedFilter = DashboardDateFilter.today;
  DashboardDateFilter get selectedFilter => _selectedFilter;

  DateTime? _customStartDate;
  DateTime? get customStartDate => _customStartDate;

  DateTime? _customEndDate;
  DateTime? get customEndDate => _customEndDate;

  SalesMetrics _metrics = SalesMetrics(
    totalRevenue: 0,
    totalCost: 0,
    grossProfit: 0,
    totalOrders: 0,
    totalItemsSold: 0,
    averageOrderValue: 0,
    cashRevenue: 0,
    qrRevenue: 0,
    cashOrderCount: 0,
    qrOrderCount: 0,
  );
  SalesMetrics get metrics => _metrics;

  List<TopSellingItem> _topItems = [];
  List<TopSellingItem> get topItems => _topItems;

  List<OrderModel> _recentOrders = [];
  List<OrderModel> get recentOrders => _recentOrders;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isExporting = false;
  bool get isExporting => _isExporting;

  String? _lastExportedPath;
  String? get lastExportedPath => _lastExportedPath;

  String? _error;
  String? get error => _error;

  DashboardController() {
    loadDashboardData();
  }

  (DateTime?, DateTime?) _calculateDateRange() {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case DashboardDateFilter.today:
        return (
          DateTime(now.year, now.month, now.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case DashboardDateFilter.yesterday:
        final y = now.subtract(const Duration(days: 1));
        return (
          DateTime(y.year, y.month, y.day),
          DateTime(y.year, y.month, y.day, 23, 59, 59),
        );
      case DashboardDateFilter.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return (
          DateTime(start.year, start.month, start.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case DashboardDateFilter.thisMonth:
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
      case DashboardDateFilter.allTime:
        return (null, null);
      case DashboardDateFilter.custom:
        return (_customStartDate, _customEndDate);
    }
  }

  Future<void> loadDashboardData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final token = _loadGuard.start();
    try {
      final (start, end) = _calculateDateRange();

      final metrics =
          await _orderDao.getSalesMetrics(startDate: start, endDate: end);
      final topItems = await _orderDao.getTopSellingItems(
          startDate: start, endDate: end, limit: 8);
      final recentOrders =
          await _orderDao.getOrders(startDate: start, endDate: end, limit: 50);

      if (_loadGuard.isStale(token)) return;

      _metrics = metrics;
      _topItems = topItems;
      _recentOrders = recentOrders;
    } catch (e) {
      if (_loadGuard.isStale(token)) return;
      _error = 'Failed to load dashboard data: $e';
      debugPrint('[DashboardController] $_error');
    } finally {
      if (!_loadGuard.isStale(token)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void setFilter(DashboardDateFilter filter) {
    _selectedFilter = filter;
    loadDashboardData();
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    _selectedFilter = DashboardDateFilter.custom;
    _customStartDate = DateTime(start.year, start.month, start.day);
    _customEndDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
    loadDashboardData();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<String?> exportToExcel(StoreSettingsModel settings) async {
    _isExporting = true;
    _error = null;
    notifyListeners();

    try {
      final (start, end) = _calculateDateRange();
      final allOrders =
          await _orderDao.getOrders(startDate: start, endDate: end, limit: 500);
      final logs = await _orderDao.getReceiptLogs(limit: 500);

      final path = await _excelExportService.exportSalesReport(
        metrics: _metrics,
        orders: allOrders,
        topItems: _topItems,
        logs: logs,
        settings: settings,
        startDate: start,
        endDate: end,
      );

      _lastExportedPath = path;
      return path;
    } catch (e) {
      _error = 'Export failed: $e';
      debugPrint('[DashboardController] $_error');
      return null;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }
}
