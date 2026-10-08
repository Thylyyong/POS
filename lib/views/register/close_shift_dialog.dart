import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/register_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../database/register_dao.dart';
import '../../services/printer_service.dart';
import '../splash/splash_screen.dart';

/// Staff Close Shift dialog.
///
/// Designed specifically for non-boss staff cashiers:
/// - Staff can close their personal shift and see their shift summary.
/// - Staff CANNOT close the register (only Boss can close the register).
/// - Allows printing a staff shift report slip.
/// - Ends shift and smoothly transitions to select role screen so data is secure.
class CloseShiftDialog extends StatefulWidget {
  const CloseShiftDialog({super.key});

  static Future<bool?> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CloseShiftDialog(),
    );

    if (result == true && context.mounted) {
      context.read<AuthController>().logout();
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, _, _) => const SplashScreen(),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
    }
    return result;
  }

  @override
  State<CloseShiftDialog> createState() => _CloseShiftDialogState();
}

class _CloseShiftDialogState extends State<CloseShiftDialog> {
  final RegisterDao _registerDao = RegisterDao();
  bool _isLoading = true;
  bool _isPrinting = false;
  Map<String, dynamic>? _shiftData;

  @override
  void initState() {
    super.initState();
    _loadShiftData();
  }

  Future<void> _loadShiftData() async {
    setState(() => _isLoading = true);
    final reg = context.read<RegisterController>();
    final auth = context.read<AuthController>();
    final session = reg.currentSession;
    final openedAt = session?.openedAt ?? DateTime.now().subtract(const Duration(hours: 4));

    try {
      final data = await _registerDao.calculateShiftSales(
        openedAt: openedAt,
        closedAt: DateTime.now(),
        branchId: auth.currentBranchId,
        cashierId: auth.currentUser.id,
        cashierName: auth.currentUser.displayName,
      );
      if (mounted) {
        setState(() {
          _shiftData = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _printShiftSlip() async {
    if (_shiftData == null) return;
    setState(() => _isPrinting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final settings = context.read<SettingsController>().settings;
      final auth = context.read<AuthController>();
      final user = auth.currentUser;
      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy hh:mm a').format(now);

      final totalOrders = _shiftData!['total_orders'] ?? 0;
      final totalRevenue = (_shiftData!['total_revenue'] as num?)?.toDouble() ?? 0.0;
      final cashSales = (_shiftData!['total_cash_sales'] as num?)?.toDouble() ?? 0.0;
      final cardSales = (_shiftData!['total_card_sales'] as num?)?.toDouble() ?? 0.0;
      final qrSales = (_shiftData!['total_qr_sales'] as num?)?.toDouble() ?? 0.0;

      final lines = <String>[
        '================================',
        '      STAFF SHIFT REPORT        ',
        '================================',
        'Date: $dateStr',
        'Staff: ${user.displayName}',
        'Role:  ${user.role.name.toUpperCase()}',
        '--------------------------------',
        'Total Orders:  $totalOrders',
        'Total Revenue: \$${totalRevenue.toStringAsFixed(2)}',
        '  Cash Sales:  \$${cashSales.toStringAsFixed(2)}',
        '  Card Sales:  \$${cardSales.toStringAsFixed(2)}',
        '  QR Sales:    \$${qrSales.toStringAsFixed(2)}',
        '================================',
        '     SHIFT ENDED - THANK YOU    ',
        ' (Register remains open for Boss)',
        '================================',
      ];

      await PrinterService().printRawLines(lines: lines, settings: settings);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Staff shift slip printed successfully!'),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Print failed: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _endShiftAndSwitchUser() {
    Navigator.of(context).pop(true);
    context.read<AuthController>().logout();
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => const SplashScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final totalOrders = _shiftData?['total_orders'] ?? 0;
    final totalRevenue = (_shiftData?['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final cashSales = (_shiftData?['total_cash_sales'] as num?)?.toDouble() ?? 0.0;
    final cardSales = (_shiftData?['total_card_sales'] as num?)?.toDouble() ?? 0.0;
    final qrSales = (_shiftData?['total_qr_sales'] as num?)?.toDouble() ?? 0.0;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: Color(0xFF0D9488),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Close Staff Shift',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Staff: ${user.displayName} (${user.role.name.toUpperCase()})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Staff Shift Explanation Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF16A34A)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are closing your staff shift. The store register remains open until the Boss performs the register reconciliation.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Shift Sales Summary Box
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Orders Completed', '$totalOrders', isBold: true),
                      const Divider(height: 14, color: Color(0xFFE2E8F0)),
                      _buildSummaryRow('Total Sales Revenue', '\$${totalRevenue.toStringAsFixed(2)}', isBold: true, highlight: true),
                      const SizedBox(height: 6),
                      _buildSummaryRow('  • Cash Collected', '\$${cashSales.toStringAsFixed(2)}'),
                      _buildSummaryRow('  • Card Collected', '\$${cardSales.toStringAsFixed(2)}'),
                      _buildSummaryRow('  • QR Payments', '\$${qrSales.toStringAsFixed(2)}'),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: _isPrinting ? null : _printShiftSlip,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print Shift Slip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: _endShiftAndSwitchUser,
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: const Text(
                      'End Shift & Lock',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? const Color(0xFF0F172A) : const Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 15 : 12.5,
              fontWeight: (isBold || highlight) ? FontWeight.bold : FontWeight.w600,
              color: highlight ? const Color(0xFF0D9488) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
