import 'package:flutter/material.dart';

import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  // Preset default users for the enterprise (1 Boss + Staff Cashier)
  static final List<UserModel> defaultUsers = [
    const UserModel(
      id: 'usr_main_boss',
      username: 'boss',
      displayName: 'Boss (Admin / Owner)',
      role: UserRole.mainBoss,
      branchId: 'all',
      branchName: 'Main Store',
      pinCode: '9999',
    ),
    const UserModel(
      id: 'usr_cashier_01',
      username: 'cashier_01',
      displayName: 'Staff Cashier (Frontline POS)',
      role: UserRole.cashier,
      branchId: 'store_a',
      branchName: 'Main Store',
      pinCode: '1234',
    ),
  ];

  UserModel _currentUser = defaultUsers.last; // Default to Staff Cashier
  UserModel get currentUser => _currentUser;

  String _currentBranchId = 'store_a';
  String get currentBranchId => _currentBranchId;

  String _currentBranchName = 'Main Store';
  String get currentBranchName => _currentBranchName;

  bool get isAdminAuthenticated => _currentUser.role != UserRole.cashier;
  bool get isMainBoss => _currentUser.isMainBoss;
  bool get isSubBoss => _currentUser.isSubBoss;
  bool get isCashier => _currentUser.isCashier;
  bool get canAccessAccounting => _currentUser.canAccessAccounting;
  bool get canSwitchBranch => _currentUser.canAccessAllBranches;
  bool get canApproveCashMovements => _currentUser.canApproveCashMovements;

  /// Authenticate user by role profile and PIN
  bool loginWithUserAndPin(UserModel user, String enteredPin) {
    if (enteredPin.trim() == user.pinCode.trim()) {
      _currentUser = user;
      if (user.branchId != null && user.branchId != 'all') {
        _currentBranchId = user.branchId!;
        _currentBranchName = user.branchName ?? 'Store Branch';
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Switch active store branch (Available to Main Boss)
  void switchBranch(String branchId, String branchName) {
    if (canSwitchBranch) {
      _currentBranchId = branchId;
      _currentBranchName = branchName;
      notifyListeners();
    }
  }

  /// Legacy support for Admin PIN
  bool authenticateAdmin(String enteredPin, String correctPin) {
    if (enteredPin.trim() == correctPin.trim()) {
      _currentUser = defaultUsers.firstWhere(
        (u) => u.isMainBoss,
        orElse: () => defaultUsers.first,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  void loginAsAdmin() {
    _currentUser = defaultUsers.firstWhere(
      (u) => u.isMainBoss,
      orElse: () => defaultUsers.first,
    );
    notifyListeners();
  }

  void loginAsCashier() {
    _currentUser = defaultUsers.firstWhere(
      (u) => u.isCashier,
      orElse: () => defaultUsers.last,
    );
    notifyListeners();
  }

  void lockAdmin() {
    _currentUser = defaultUsers.firstWhere(
      (u) => u.isCashier,
      orElse: () => defaultUsers.last,
    );
    notifyListeners();
  }

  void logout() {
    _currentUser = defaultUsers.firstWhere(
      (u) => u.isCashier,
      orElse: () => defaultUsers.last,
    );
    notifyListeners();
  }
}
