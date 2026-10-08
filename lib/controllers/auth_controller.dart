import 'package:flutter/material.dart';

import '../database/user_dao.dart';
import '../models/user_model.dart';

class AuthController extends ChangeNotifier {
  final UserDao _userDao = UserDao();

  // In-memory list of all staff loaded from DB
  List<UserModel> _allUsers = List.from(defaultUsers);
  List<UserModel> get allUsers => List.unmodifiable(_allUsers);
  static List<UserModel> get screenUsers => defaultUsers;

  // Preset fallback users if DB is empty
  static final List<UserModel> defaultUsers = [
    const UserModel(
      id: 'usr_owner',
      username: 'owner',
      displayName: 'Owner (Boss)',
      role: UserRole.owner,
      branchId: 'main',
      branchName: 'Main Store',
      pinCode: '9999',
    ),
    const UserModel(
      id: 'usr_cashier',
      username: 'cashier',
      displayName: 'Staff Cashier',
      role: UserRole.cashier,
      branchId: 'main',
      branchName: 'Main Store',
      pinCode: '1234',
    ),
  ];

  AuthController() {
    loadUsersFromDb();
  }

  Future<void> loadUsersFromDb() async {
    try {
      final dbUsers = await _userDao.getAllUsers();
      if (dbUsers.isNotEmpty) {
        _allUsers = dbUsers;
        notifyListeners();
      } else {
        _allUsers = List.from(defaultUsers);
      }
    } catch (_) {
      _allUsers = List.from(defaultUsers);
    }
  }

  UserModel _currentUser = defaultUsers[1]; // Default to Staff Cashier
  UserModel get currentUser => _currentUser;

  String _currentBranchId = 'main';
  String get currentBranchId => _currentBranchId;

  String _currentBranchName = 'Main Store';
  String get currentBranchName => _currentBranchName;

  // ── Role shortcuts ────────────────────────────────────────────────────────

  bool get isAdminAuthenticated =>
      _currentUser.role != UserRole.cashier && _currentUser.role != UserRole.chef;
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

  // ── Authentication ────────────────────────────────────────────────────────

  /// Authenticate user by profile + PIN (for selector screen)
  bool loginWithUserAndPin(UserModel user, String enteredPin) {
    // Locked user cannot log in — regardless of correct PIN
    if (user.isLocked) return false;
    if (enteredPin.trim() == user.pinCode.trim()) {
      _currentUser = user;
      _syncBranch(user);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Logout current session safely
  void logout() {
    _currentUser = defaultUsers.last;
    notifyListeners();
  }

  /// Authenticate by PIN alone (numpad login) — locked users are rejected in DAO
  Future<UserModel?> loginWithPin(String enteredPin) async {
    final cleanPin = enteredPin.trim();

    // 1. SQLite lookup (UserDao.getUserByPin already returns null for locked users)
    try {
      final user = await _userDao.getUserByPin(cleanPin);
      if (user != null) {
        _currentUser = user;
        _syncBranch(user);
        notifyListeners();
        return user;
      }
    } catch (_) {}

    // 2. Fallback to in-memory list and default users (never allows locked users)
    for (final u in _allUsers) {
      if (u.pinCode == cleanPin && !u.isLocked) {
        _currentUser = u;
        _syncBranch(u);
        notifyListeners();
        return u;
      }
    }
    for (final u in defaultUsers) {
      if (u.pinCode == cleanPin && !u.isLocked) {
        _currentUser = u;
        _syncBranch(u);
        notifyListeners();
        return u;
      }
    }
    return null;
  }

  void _syncBranch(UserModel user) {
    if (user.branchId != null && user.branchId != 'all') {
      _currentBranchId = user.branchId!;
      _currentBranchName = user.branchName ?? 'Store Branch';
    }
  }

  // ── Staff Management (Owner only) ─────────────────────────────────────────

  /// Add a new staff member. Returns an error message or null on success.
  Future<String?> addStaff({
    required String name,
    required UserRole role,
    required String pin,
  }) async {
    if (name.trim().isEmpty) return 'Name cannot be empty.';
    if (pin.length != 4 || int.tryParse(pin) == null) return 'PIN must be exactly 4 digits.';

    // Check PIN uniqueness
    final pinTaken = await _userDao.isPinTaken(pin);
    if (pinTaken) return 'This PIN is already used by another staff member.';

    final newUser = UserModel.newStaff(
      displayName: name.trim(),
      role: role,
      pinCode: pin,
    );

    await _userDao.saveUser(newUser);
    await loadUsersFromDb();
    return null;
  }

  /// Update an existing staff member's info
  Future<String?> updateStaff({
    required String userId,
    String? newName,
    String? newPin,
    UserRole? newRole,
  }) async {
    if (newPin != null) {
      if (newPin.length != 4 || int.tryParse(newPin) == null) {
        return 'PIN must be exactly 4 digits.';
      }
      final pinTaken = await _userDao.isPinTaken(newPin, excludeUserId: userId);
      if (pinTaken) return 'This PIN is already used by another staff member.';
      await _userDao.updateUserPin(userId, newPin);
    }
    if (newName != null && newName.trim().isNotEmpty) {
      await _userDao.updateUserName(userId, newName.trim());
    }
    if (newRole != null) {
      await _userDao.updateUserRole(userId, newRole);
    }
    await loadUsersFromDb();
    return null;
  }

  /// Toggle lock/unlock for a staff member.
  /// Owner cannot lock themselves.
  Future<String?> toggleStaffLock(String userId) async {
    if (userId == _currentUser.id) {
      return 'You cannot lock your own account.';
    }
    final user = await _userDao.getUserById(userId);
    if (user == null) return 'User not found.';
    if (user.role == UserRole.owner || user.role == UserRole.mainBoss) {
      return 'Cannot lock the Owner account.';
    }
    await _userDao.toggleLock(userId);
    await loadUsersFromDb();
    return null;
  }

  /// Delete a staff member
  Future<String?> deleteStaff(String userId) async {
    if (userId == _currentUser.id) return 'Cannot delete currently logged-in user.';
    final user = await _userDao.getUserById(userId);
    if (user == null) return 'User not found.';
    if (user.role == UserRole.owner || user.role == UserRole.mainBoss) {
      return 'Cannot delete the Owner account.';
    }
    await _userDao.deleteUser(userId);
    await loadUsersFromDb();
    return null;
  }

  // ── PIN change ────────────────────────────────────────────────────────────

  Future<bool> changeUserPin({
    required String userId,
    required String currentPin,
    required String newPin,
    bool isAdminOverride = false,
  }) async {
    UserModel? dbUser;
    try {
      dbUser = await _userDao.getUserById(userId);
    } catch (_) {}

    final user = dbUser ?? _allUsers.firstWhere((u) => u.id == userId, orElse: () => _currentUser);

    if (!isAdminOverride && user.pinCode.trim() != currentPin.trim()) {
      return false;
    }

    try {
      await _userDao.updateUserPin(userId, newPin.trim());
      await loadUsersFromDb();
    } catch (_) {}

    for (int i = 0; i < defaultUsers.length; i++) {
      if (defaultUsers[i].id == userId) {
        defaultUsers[i] = defaultUsers[i].copyWith(pinCode: newPin.trim());
      }
    }
    for (int i = 0; i < _allUsers.length; i++) {
      if (_allUsers[i].id == userId) {
        _allUsers[i] = _allUsers[i].copyWith(pinCode: newPin.trim());
      }
    }

    if (_currentUser.id == userId) {
      _currentUser = _currentUser.copyWith(pinCode: newPin.trim());
    }
    notifyListeners();
    return true;
  }

  // ── Navigation / Legacy helpers ───────────────────────────────────────────

  void switchBranch(String branchId, String branchName) {
    if (canSwitchBranch) {
      _currentBranchId = branchId;
      _currentBranchName = branchName;
      notifyListeners();
    }
  }

  bool authenticateAdmin(String enteredPin, String correctPin) {
    if (enteredPin.trim() == correctPin.trim()) {
      final owner = _allUsers.firstWhere(
        (u) => u.isOwner,
        orElse: () => defaultUsers.first,
      );
      _currentUser = owner;
      notifyListeners();
      return true;
    }
    return false;
  }

  void loginAsAdmin() {
    _currentUser = _allUsers.firstWhere(
      (u) => u.isOwner,
      orElse: () => defaultUsers.first,
    );
    notifyListeners();
  }

  void loginAsCashier() {
    final cashier = _allUsers.firstWhere(
      (u) => u.isCashier && !u.isLocked,
      orElse: () => defaultUsers.last,
    );
    _currentUser = cashier;
    _syncBranch(cashier);
    notifyListeners();
  }

  void loginAsChef() {
    final chef = _allUsers.firstWhere(
      (u) => u.isChef && !u.isLocked,
      orElse: () => defaultUsers.last,
    );
    _currentUser = chef;
    notifyListeners();
  }

  void lockAdmin() {
    loginAsCashier();
  }
}
