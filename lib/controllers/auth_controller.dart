import 'package:flutter/material.dart';

import '../database/user_dao.dart';
import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  final UserDao _userDao = UserDao();

  // Preset default users for the enterprise
  static final List<UserModel> defaultUsers = [
    const UserModel(
      id: 'usr_owner',
      username: 'owner',
      displayName: 'Owner (Boss)',
      role: UserRole.owner,
      branchId: 'all',
      branchName: 'Main Store',
      pinCode: '9999',
    ),
    const UserModel(
      id: 'usr_sub_boss_1',
      username: 'sub_boss_1',
      displayName: 'Sub Boss 1 (Store A)',
      role: UserRole.subBoss,
      branchId: 'store_a',
      branchName: 'Store A',
      pinCode: '1111',
    ),
    const UserModel(
      id: 'usr_sub_boss_2',
      username: 'sub_boss_2',
      displayName: 'Sub Boss 2 (Store B)',
      role: UserRole.subBoss,
      branchId: 'store_b',
      branchName: 'Store B',
      pinCode: '2222',
    ),
    const UserModel(
      id: 'usr_cashier',
      username: 'cashier',
      displayName: 'Staff Cashier (Frontline POS)',
      role: UserRole.cashier,
      branchId: 'store_a',
      branchName: 'Main Store',
      pinCode: '1234',
    ),
    const UserModel(
      id: 'usr_chef',
      username: 'chef',
      displayName: 'Kitchen Chef (KDS)',
      role: UserRole.chef,
      branchId: 'store_a',
      branchName: 'Main Store',
      pinCode: '5555',
    ),
  ];

  /// Only Boss and Staff Cashier for UI screen display and selection
  static List<UserModel> get screenUsers => [
    defaultUsers[0], // Owner (Boss)
    defaultUsers[3], // Staff Cashier
  ];

  AuthController() {
    loadUsersFromDb();
  }

  Future<void> loadUsersFromDb() async {
    try {
      final dbUsers = await _userDao.getAllUsers();
      if (dbUsers.isNotEmpty) {
        for (final dbUser in dbUsers) {
          final idx = defaultUsers.indexWhere((u) => u.id == dbUser.id);
          if (idx >= 0) {
            defaultUsers[idx] = defaultUsers[idx].copyWith(pinCode: dbUser.pinCode);
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  UserModel _currentUser = defaultUsers[3]; // Default to Staff Cashier
  UserModel get currentUser => _currentUser;

  String _currentBranchId = 'store_a';
  String get currentBranchId => _currentBranchId;

  String _currentBranchName = 'Main Store';
  String get currentBranchName => _currentBranchName;

  /// Update user PIN code and persist directly to SQLite database
  Future<bool> changeUserPin({
    required String userId,
    required String currentPin,
    required String newPin,
    bool isAdminOverride = false,
  }) async {
    // 1. Verify current PIN against database or memory
    UserModel? dbUser;
    try {
      dbUser = await _userDao.getUserById(userId);
    } catch (_) {}

    final user = dbUser ??
        defaultUsers.firstWhere(
          (u) => u.id == userId,
          orElse: () => _currentUser,
        );

    if (!isAdminOverride && user.pinCode.trim() != currentPin.trim()) {
      return false;
    }

    final updatedUser = user.copyWith(pinCode: newPin.trim());

    // 2. Persist to SQLite users table
    try {
      await _userDao.saveUser(updatedUser);
      await _userDao.updateUserPin(userId, newPin.trim());
    } catch (_) {}

    // 3. Update in-memory defaultUsers list & currentUser if matched
    final idx = defaultUsers.indexWhere((u) => u.id == userId);
    if (idx >= 0) {
      defaultUsers[idx] = updatedUser;
    }
    if (_currentUser.id == userId) {
      _currentUser = updatedUser;
    }

    notifyListeners();
    return true;
  }

  bool get isAdminAuthenticated => _currentUser.role != UserRole.cashier && _currentUser.role != UserRole.chef;
  bool get isOwner => _currentUser.isOwner;
  bool get isMainBoss => _currentUser.isMainBoss;
  bool get isSubBoss => _currentUser.isSubBoss;
  bool get isCashier => _currentUser.isCashier;
  bool get isChef => _currentUser.isChef;
  bool get canAccessAccounting => _currentUser.canAccessAccounting;
  bool get canSwitchBranch => _currentUser.canAccessAllBranches;
  bool get canApproveCashMovements => _currentUser.canApproveCashMovements;
  bool get canAccessKitchen => _currentUser.canAccessKitchen;
  bool get canAccessPos => _currentUser.canAccessPos;
  bool get canAccessReports => _currentUser.canAccessReports;
  bool get canAccessSettings => _currentUser.canAccessSettings;

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

  /// Authenticate by PIN alone (from on-screen numpad)
  Future<UserModel?> loginWithPin(String enteredPin) async {
    final cleanPin = enteredPin.trim();

    // 1. Check in SQLite users table first
    try {
      final user = await _userDao.getUserByPin(cleanPin);
      if (user != null) {
        _currentUser = user;
        if (user.branchId != null && user.branchId != 'all') {
          _currentBranchId = user.branchId!;
          _currentBranchName = user.branchName ?? 'Store Branch';
        }
        notifyListeners();
        return user;
      }
    } catch (_) {}

    // 2. Fallback to defaultUsers list
    for (final u in defaultUsers) {
      if (u.pinCode == cleanPin) {
        _currentUser = u;
        if (u.branchId != null && u.branchId != 'all') {
          _currentBranchId = u.branchId!;
          _currentBranchName = u.branchName ?? 'Store Branch';
        }
        notifyListeners();
        return u;
      }
    }
    return null;
  }

  /// Switch active store branch (Available to Owner / Main Boss)
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
        (u) => u.isOwner,
        orElse: () => defaultUsers.first,
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  void loginAsAdmin() {
    _currentUser = defaultUsers.firstWhere(
      (u) => u.isOwner,
      orElse: () => defaultUsers.first,
    );
    notifyListeners();
  }

  void loginAsCashier() {
    _currentUser = defaultUsers.firstWhere(
      (u) => u.isCashier,
      orElse: () => defaultUsers[3],
    );
    notifyListeners();
  }

  void loginAsChef() {
    _currentUser = defaultUsers.firstWhere(
      (u) => u.isChef,
      orElse: () => defaultUsers.last,
    );
    notifyListeners();
  }

  void lockAdmin() {
    _currentUser = defaultUsers.firstWhere(
      (u) => u.isCashier,
      orElse: () => defaultUsers[3],
    );
    notifyListeners();
  }

  void logout() {
    _currentUser = defaultUsers.firstWhere(
      (u) => u.isCashier,
      orElse: () => defaultUsers[3],
    );
    notifyListeners();
  }
}
