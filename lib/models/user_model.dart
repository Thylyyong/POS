enum UserRole {
  mainBoss, // Master Owner / Super Admin (Pin: 9999) - Access to all stores & global P&L
  subBoss,  // Store Manager (Store A Pin: 1111, Store B Pin: 2222) - Access to own store & store P&L
  cashier,  // Cashier Staff (Pin: 1234) - Access to POS register only
}

class UserModel {
  final String id;
  final String username;
  final String displayName;
  final UserRole role;
  final String? branchId; // 'all', 'store_a', 'store_b'
  final String? branchName;
  final String pinCode;

  const UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    this.branchId,
    this.branchName,
    required this.pinCode,
  });

  bool get isMainBoss => role == UserRole.mainBoss;
  bool get isSubBoss => role == UserRole.subBoss;
  bool get isCashier => role == UserRole.cashier;

  bool get canAccessAllBranches => isMainBoss;
  bool get canAccessAccounting => isMainBoss || isSubBoss;
  bool get canApproveCashMovements => isMainBoss || isSubBoss;
  bool get canManageInventory => isMainBoss || isSubBoss;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'role': role.name,
      'branch_id': branchId,
      'branch_name': branchName,
      'pin_code': pinCode,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.cashier,
      ),
      branchId: map['branch_id'] as String?,
      branchName: map['branch_name'] as String?,
      pinCode: map['pin_code'] as String? ?? '1234',
    );
  }
}
