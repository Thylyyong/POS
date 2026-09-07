enum UserRole {
  owner, // Master Owner / Super Admin (Pin: 9999) - Full Access
  cashier, // Cashier Staff (Pin: 1234) - Access to POS register only
  chef, // Kitchen Chef (Pin: 5555) - Kitchen Display Only
  mainBoss, // Alias for backward compatibility
  subBoss, // Store Manager (Store A Pin: 1111, Store B Pin: 2222)
}

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.owner:
      case UserRole.mainBoss:
        return 'OWNER';
      case UserRole.cashier:
        return 'CASHIER';
      case UserRole.chef:
        return 'CHEF';
      case UserRole.subBoss:
        return 'SUB_BOSS';
    }
  }

  static UserRole fromString(String val) {
    switch (val.toUpperCase()) {
      case 'OWNER':
      case 'MAINBOSS':
        return UserRole.owner;
      case 'CHEF':
        return UserRole.chef;
      case 'SUB_BOSS':
      case 'SUBBOSS':
        return UserRole.subBoss;
      case 'CASHIER':
      default:
        return UserRole.cashier;
    }
  }
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

  bool get isOwner => role == UserRole.owner || role == UserRole.mainBoss;
  bool get isMainBoss => isOwner;
  bool get isSubBoss => role == UserRole.subBoss;
  bool get isCashier => role == UserRole.cashier;
  bool get isChef => role == UserRole.chef;

  bool get canAccessAllBranches => isOwner;
  bool get canAccessAccounting => isOwner || isSubBoss;
  bool get canApproveCashMovements => isOwner || isSubBoss;
  bool get canManageInventory => isOwner || isSubBoss;
  bool get canAccessKitchen => isChef || isOwner;
  bool get canAccessPos => isCashier || isOwner;
  bool get canAccessReports => isOwner || isSubBoss;
  bool get canAccessSettings => isOwner;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': displayName,
      'username': username,
      'display_name': displayName,
      'role': role.displayName,
      'branch_id': branchId,
      'branch_name': branchName,
      'pin_code': pinCode,
    };
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'name': displayName,
      'pin_code': pinCode,
      'role': role.displayName,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final name = (map['name'] ?? map['display_name'] ?? map['username'] ?? '') as String;
    final roleStr = (map['role'] as String? ?? 'CASHIER');

    return UserModel(
      id: map['id'] as String,
      username: map['username'] as String? ?? name.toLowerCase().replaceAll(' ', '_'),
      displayName: name,
      role: UserRoleExtension.fromString(roleStr),
      branchId: map['branch_id'] as String?,
      branchName: map['branch_name'] as String?,
      pinCode: map['pin_code'] as String? ?? '1234',
    );
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? displayName,
    UserRole? role,
    String? branchId,
    String? branchName,
    String? pinCode,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      pinCode: pinCode ?? this.pinCode,
    );
  }
}
