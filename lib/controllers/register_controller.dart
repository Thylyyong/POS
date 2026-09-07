import 'package:flutter/material.dart';

import '../database/register_dao.dart';
import '../models/cash_movement_model.dart';
import '../models/register_session_model.dart';
import '../services/printer_service.dart';

class RegisterController extends ChangeNotifier {
  final RegisterDao _dao = RegisterDao();
  final PrinterService _printerService = PrinterService();

  RegisterSessionModel? _activeSession;
  RegisterSessionModel? get activeSession => _activeSession;

  List<CashMovementModel> _activeMovements = [];
  List<CashMovementModel> get activeMovements => _activeMovements;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool get isSessionOpen => _activeSession != null && _activeSession!.isOpen;

  /// Load current active register session
  Future<void> loadActiveSession({String? branchId}) async {
    _isLoading = true;
    notifyListeners();

    _activeSession = await _dao.getActiveSession(branchId: branchId);
    if (_activeSession != null) {
      _activeMovements = await _dao.getSessionMovements(_activeSession!.id);
    } else {
      _activeMovements = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Open Register (Opening Control)
  Future<RegisterSessionModel> openRegister({
    required double openingCash,
    String? openingNotes,
    required String branchId,
    required String branchName,
    required String cashierId,
    required String cashierName,
    bool kickDrawer = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    _activeSession = await _dao.openSession(
      branchId: branchId,
      branchName: branchName,
      cashierId: cashierId,
      cashierName: cashierName,
      openingCash: openingCash,
      openingNotes: openingNotes,
    );

    _activeMovements = [];
    _isLoading = false;
    notifyListeners();

    // Kick cash drawer open via hardware ESC/POS pulse
    if (kickDrawer) {
      await _printerService.kickCashDrawer();
    }

    return _activeSession!;
  }

  /// Add Cash In or Cash Out petty adjustment
  Future<CashMovementModel?> addCashMovement({
    required CashMovementType type,
    required double amount,
    required String reason,
    required String authorizedById,
    String? authorizedByName,
    bool kickDrawer = true,
  }) async {
    if (_activeSession == null) return null;

    final movement = await _dao.addCashMovement(
      sessionId: _activeSession!.id,
      type: type,
      amount: amount,
      reason: reason,
      authorizedById: authorizedById,
      authorizedByName: authorizedByName,
    );

    _activeMovements.add(movement);

    // Refresh active session from DB to update totals
    _activeSession = await _dao.getActiveSession(
      branchId: _activeSession!.branchId,
    );
    notifyListeners();

    if (kickDrawer) {
      await _printerService.kickCashDrawer();
    }

    return movement;
  }

  /// Calculate live closing summary (Sales + Cash In/Out + Expected Totals)
  Future<Map<String, dynamic>> calculateClosingSummary() async {
    if (_activeSession == null) {
      return {
        'opening_cash': 0.0,
        'total_orders': 0,
        'total_revenue': 0.0,
        'total_cash_sales': 0.0,
        'total_card_sales': 0.0,
        'total_qr_sales': 0.0,
        'total_cash_in': 0.0,
        'total_cash_out': 0.0,
        'expected_cash': 0.0,
      };
    }

    final salesData = await _dao.calculateShiftSales(
      openedAt: _activeSession!.openedAt,
      branchId: _activeSession!.branchId,
    );

    double opening = _activeSession!.openingCash;
    double cashSales = salesData['total_cash_sales'] as double;
    double cardSales = salesData['total_card_sales'] as double;
    double qrSales = salesData['total_qr_sales'] as double;
    int ordersCount = salesData['total_orders'] as int;

    double cashIn = 0.0;
    double cashOut = 0.0;
    for (var m in _activeMovements) {
      if (m.isCashIn) cashIn += m.amount;
      if (m.isCashOut) cashOut += m.amount;
    }

    double expectedCash = opening + cashSales + cashIn - cashOut;

    return {
      'opening_cash': opening,
      'total_orders': ordersCount,
      'total_revenue': salesData['total_revenue'] as double,
      'total_cash_sales': cashSales,
      'total_card_sales': cardSales,
      'total_qr_sales': qrSales,
      'total_cash_in': cashIn,
      'total_cash_out': cashOut,
      'expected_cash': expectedCash,
    };
  }

  /// Close Register (Reconcile and lock session)
  Future<bool> closeRegister({
    required double closingCashCounted,
    required double closingCardCounted,
    double closingCustomerAccountCounted = 0.0,
    String? closingNotes,
  }) async {
    if (_activeSession == null) return false;

    final summary = await calculateClosingSummary();
    double expectedCash = summary['expected_cash'] as double;
    double cashDifference = closingCashCounted - expectedCash;

    final success = await _dao.closeSession(
      sessionId: _activeSession!.id,
      closingCashCounted: closingCashCounted,
      closingCardCounted: closingCardCounted,
      closingCustomerAccountCounted: closingCustomerAccountCounted,
      expectedCash: expectedCash,
      cashDifference: cashDifference,
      closingNotes: closingNotes,
      totalOrders: summary['total_orders'] as int,
      totalCashSales: summary['total_cash_sales'] as double,
      totalCardSales: summary['total_card_sales'] as double,
      totalQrSales: summary['total_qr_sales'] as double,
      totalCashIn: summary['total_cash_in'] as double,
      totalCashOut: summary['total_cash_out'] as double,
    );

    if (success) {
      _activeSession = null;
      _activeMovements = [];
      notifyListeners();
    }

    return success;
  }

  /// Trigger hardware cash drawer test kick
  Future<List<int>> kickDrawerDirectly() async {
    return await _printerService.kickCashDrawer();
  }
}
