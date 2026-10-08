import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';

/// Owner-only screen to manage staff: add, edit PIN, change role, lock/unlock, delete.
class StaffManagementScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const StaffManagementScreen({super.key, this.onBack});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  bool _loadingAction = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    // Gate: only owner can access this screen
    if (!auth.isOwner) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.lock_rounded, size: 48, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Owner Access Only',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Only the Owner (Boss) can manage staff accounts.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final users = auth.allUsers;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                // Back Button (arrow back icon)
                Tooltip(
                  message: 'Back',
                  child: InkWell(
                    onTap: () {
                      if (widget.onBack != null) {
                        widget.onBack!();
                      } else if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_rounded, size: 22, color: Color(0xFF7C3AED)),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Staff Management',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Add, edit, lock or remove staff accounts',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    elevation: 0,
                  ),
                  onPressed: () => _showAddStaffDialog(context, auth),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Staff', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Role legend
          Container(
            color: const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                _roleBadge('Owner', const Color(0xFF7C3AED)),
                const SizedBox(width: 10),
                _roleBadge('Cashier', const Color(0xFF0D9488)),
                const SizedBox(width: 10),
                _roleBadge('Chef', const Color(0xFFF97316)),
                const Spacer(),
                Text(
                  '${users.length} staff members',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Staff list
          Expanded(
            child: users.isEmpty
                ? const Center(
                    child: Text('No staff members found.', style: TextStyle(color: Color(0xFF64748B))),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: users.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return _buildStaffCard(context, user, auth);
                    },
                  ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _roleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildStaffCard(BuildContext context, UserModel user, AuthController auth) {
    final isOwner = user.role == UserRole.owner || user.role == UserRole.mainBoss;
    final isSelf = user.id == auth.currentUser.id;
    final Color roleColor = _roleColor(user.role);

    return Container(
      decoration: BoxDecoration(
        color: user.isLocked ? const Color(0xFFFEF2F2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: user.isLocked ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: user.isLocked
                    ? const Color(0xFFFECACA)
                    : roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                user.isLocked ? Icons.lock_rounded : _roleIcon(user.role),
                size: 22,
                color: user.isLocked ? const Color(0xFFDC2626) : roleColor,
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.displayName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: user.isLocked ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'You',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0D9488)),
                          ),
                        ),
                      ],
                      if (user.isLocked) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LOCKED',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          user.role.displayName,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: roleColor),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Show PIN only to owner
                      Text(
                        'PIN: ${user.pinCode}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionButton(
                  icon: Icons.edit_rounded,
                  color: const Color(0xFF0284C7),
                  tooltip: 'Edit name / PIN',
                  onTap: () => _showEditStaffDialog(context, user, auth),
                ),
                if (!isOwner && !isSelf) ...[
                  const SizedBox(width: 8),
                  _actionButton(
                    icon: user.isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                    color: user.isLocked ? const Color(0xFF059669) : const Color(0xFFF97316),
                    tooltip: user.isLocked ? 'Unlock account' : 'Lock account',
                    onTap: () => _toggleLock(context, user, auth),
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    icon: Icons.delete_rounded,
                    color: const Color(0xFFDC2626),
                    tooltip: 'Delete staff',
                    onTap: () => _deleteStaff(context, user, auth),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: _loadingAction ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.owner:
      case UserRole.mainBoss:
        return const Color(0xFF7C3AED);
      case UserRole.cashier:
        return const Color(0xFF0D9488);
      case UserRole.chef:
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.owner:
      case UserRole.mainBoss:
        return Icons.admin_panel_settings_rounded;
      case UserRole.cashier:
        return Icons.point_of_sale_rounded;
      case UserRole.chef:
        return Icons.restaurant_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Future<void> _showAddStaffDialog(BuildContext context, AuthController auth) async {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    UserRole selectedRole = UserRole.cashier;
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: Color(0xFF7C3AED)),
              SizedBox(width: 10),
              Text('Add New Staff'),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(errorMsg!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                        ),
                      ],
                    ),
                  ),
                const Text('Full Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. John Smith',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Role', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                DropdownButtonFormField<UserRole>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: UserRole.cashier, child: Text('Cashier')),
                    DropdownMenuItem(value: UserRole.chef, child: Text('Chef / Kitchen')),
                  ],
                  onChanged: (val) => setDialogState(() => selectedRole = val ?? UserRole.cashier),
                ),
                const SizedBox(height: 14),
                const Text('4-Digit PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _loadingAction = true);
                final err = await auth.addStaff(
                  name: nameCtrl.text,
                  role: selectedRole,
                  pin: pinCtrl.text,
                );
                setState(() => _loadingAction = false);
                if (err != null) {
                  setDialogState(() => errorMsg = err);
                } else {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${nameCtrl.text.trim()} added!'),
                      backgroundColor: const Color(0xFF059669),
                    ),
                  );
                }
              },
              child: const Text('Add Staff', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditStaffDialog(BuildContext context, UserModel user, AuthController auth) async {
    final nameCtrl = TextEditingController(text: user.displayName);
    final pinCtrl = TextEditingController();
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, color: Color(0xFF0284C7)),
              const SizedBox(width: 10),
              Text('Edit: ${user.displayName}'),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(errorMsg!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                  ),
                const Text('Display Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'New PIN (leave blank to keep current)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  style: const TextStyle(fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Enter new PIN...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _loadingAction = true);
                final err = await auth.updateStaff(
                  userId: user.id,
                  newName: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                  newPin: pinCtrl.text.isEmpty ? null : pinCtrl.text,
                );
                setState(() => _loadingAction = false);
                if (err != null) {
                  setDialogState(() => errorMsg = err);
                } else {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Updated successfully!'),
                      backgroundColor: Color(0xFF0284C7),
                    ),
                  );
                }
              },
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLock(BuildContext context, UserModel user, AuthController auth) async {
    final messenger = ScaffoldMessenger.of(context);
    final action = user.isLocked ? 'Unlock' : 'Lock';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('$action Account?'),
        content: Text(
          user.isLocked
              ? '${user.displayName} will be able to log in again.'
              : '${user.displayName} will not be able to log in until unlocked.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isLocked ? const Color(0xFF059669) : const Color(0xFFF97316),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loadingAction = true);
    final err = await auth.toggleStaffLock(user.id);
    setState(() => _loadingAction = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(err ?? '${user.displayName} ${action.toLowerCase()}ed.'),
        backgroundColor: err != null ? const Color(0xFFDC2626) : const Color(0xFF059669),
      ),
    );
  }

  Future<void> _deleteStaff(BuildContext context, UserModel user, AuthController auth) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Staff?', style: TextStyle(color: Color(0xFFDC2626))),
        content: Text('Remove "${user.displayName}"?\n\nThis cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loadingAction = true);
    final err = await auth.deleteStaff(user.id);
    setState(() => _loadingAction = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(err ?? '${user.displayName} removed from staff.'),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }
}
