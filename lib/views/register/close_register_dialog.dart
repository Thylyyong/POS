import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/register_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../services/printer_service.dart';
import 'cash_in_out_dialog.dart';
import 'close_shift_dialog.dart';
import '../../core/theme/asset_theme.dart';
import '../../core/theme/sprite_icons.dart';
import '../../widgets/app_svg_icon.dart';
import 'widgets/dual_currency_piece_counter_dialog.dart';
import '../splash/splash_screen.dart';

class CloseRegisterDialog extends StatefulWidget {
  const CloseRegisterDialog({super.key});

  /// Show the Close Register dialog.
  /// Requires owner PIN before proceeding — staff cannot close register.
  /// If called by staff, opens CloseShiftDialog instead.
  static Future<bool?> show(BuildContext context) async {
    // Staff can only close shift, only Boss can close register
    final auth = context.read<AuthController>();
    if (!auth.isOwner) {
      return CloseShiftDialog.show(context);
    }

    // Require owner PIN even if already logged in as owner for extra security
    final settings = context.read<SettingsController>().settings;
    final pinVerified = await _showOwnerPinGate(context, settings.adminPin);
    if (!pinVerified || !context.mounted) return null;

    final closed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CloseRegisterDialog(),
    );

    if (closed == true && context.mounted) {
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
    return closed;
  }

  /// Show a PIN entry gate specifically for register close (security layer)
  static Future<bool> _showOwnerPinGate(BuildContext context, String correctPin) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _RegisterClosePinDialog(correctPin: correctPin),
    );
    return result ?? false;
  }

  @override
  State<CloseRegisterDialog> createState() => _CloseRegisterDialogState();
}

/// PIN gate dialog specifically for register close action
class _RegisterClosePinDialog extends StatefulWidget {
  final String correctPin;
  const _RegisterClosePinDialog({required this.correctPin});

  @override
  State<_RegisterClosePinDialog> createState() => _RegisterClosePinDialogState();
}

class _RegisterClosePinDialogState extends State<_RegisterClosePinDialog> {
  String _pin = '';
  String? _error;

  void _onKey(String digit) {
    if (_pin.length >= 4) return;
    final next = _pin + digit;
    setState(() {
      _pin = next;
      _error = null;
    });
  }

  void _verify(String pin) {
    final settings = context.read<SettingsController>().settings;
    if (settings.verifyAdminPin(pin) || pin == widget.correctPin) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _pin = '';
        _error = 'Wrong PIN. Only the owner can close the register.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.lock_rounded, size: 32, color: Color(0xFF7C3AED)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Owner PIN Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Enter owner PIN to close the register',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0),
                    border: Border.all(
                      color: filled ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11.5)),
            ],
            const SizedBox(height: 20),
            // Numpad
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ...[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => _NumpadButton(
                  label: '$n',
                  onTap: () => _onKey('$n'),
                )),
                _NumpadButton(
                  label: 'C',
                  onTap: () => setState(() {
                    _pin = '';
                    _error = null;
                  }),
                ),
                _NumpadButton(label: '0', onTap: () => _onKey('0')),
                _NumpadButton(
                  label: '⌫',
                  onTap: () {
                    if (_pin.isNotEmpty) {
                      setState(() {
                        _pin = _pin.substring(0, _pin.length - 1);
                        _error = null;
                      });
                    }
                  },
                  isDestructive: true,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pin.length == 4 ? () => _verify(_pin) : null,
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumpadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _NumpadButton({required this.label, required this.onTap, this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDestructive ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDestructive ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}

class _CloseRegisterDialogState extends State<CloseRegisterDialog> {
  final TextEditingController _cashCountCtrl = TextEditingController();
  final TextEditingController _cardCountCtrl = TextEditingController();
  final TextEditingController _closingNoteCtrl = TextEditingController();

  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final reg = context.read<RegisterController>();
    final summary = await reg.calculateClosingSummary();

    setState(() {
      _summary = summary;
      _isLoading = false;

      final expectedCash = (summary['expected_cash'] as num?)?.toDouble() ?? 0.0;
      final cardSales = (summary['total_card_sales'] as num?)?.toDouble() ?? 0.0;
      _cashCountCtrl.text = expectedCash.toStringAsFixed(2);
      _cardCountCtrl.text = cardSales.toStringAsFixed(2);
    });
  }

  Future<void> _printDailySaleReport() async {
    if (_summary == null) return;
    setState(() => _isPrinting = true);
    try {
      final settings = context.read<SettingsController>().settings;
      final auth = context.read<AuthController>();
      final summary = _summary!;
      
      // Build a simple text report for thermal printing
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
      final lines = <String>[
        '================================',
        '     REGISTER CLOSING REPORT    ',
        '================================',
        'Date: $dateStr',
        'Cashier: ${auth.currentUser.displayName}',
        '--------------------------------',
        'Opening Cash: \$${(summary['opening_cash'] as double).toStringAsFixed(2)}',
        '--------------------------------',
        'Total Orders: ${summary['total_orders']}',
        'Total Revenue: \$${(summary['total_revenue'] as double).toStringAsFixed(2)}',
        '  Cash Sales: \$${(summary['total_cash_sales'] as double).toStringAsFixed(2)}',
        '  Card Sales: \$${(summary['total_card_sales'] as double).toStringAsFixed(2)}',
        '  QR Sales:   \$${(summary['total_qr_sales'] as double).toStringAsFixed(2)}',
        '--------------------------------',
        'Cash In:  \$${(summary['total_cash_in'] as double).toStringAsFixed(2)}',
        'Cash Out: \$${(summary['total_cash_out'] as double).toStringAsFixed(2)}',
        '--------------------------------',
        'Expected Cash: \$${(summary['expected_cash'] as double).toStringAsFixed(2)}',
        'Counted Cash:  \$${(double.tryParse(_cashCountCtrl.text) ?? 0).toStringAsFixed(2)}',
        '================================',
        '  *** REGISTER CLOSED ***       ',
        '================================',
      ];
      
      final printerService = PrinterService();
      await printerService.printRawLines(lines: lines, settings: settings);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Closing report printed!'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  void dispose() {
    _cashCountCtrl.dispose();
    _cardCountCtrl.dispose();
    _closingNoteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reg = context.watch<RegisterController>();
    final activeSession = reg.activeSession;

    if (_isLoading || _summary == null) {
      return const Dialog(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Calculating Register Balances...'),
            ],
          ),
        ),
      );
    }

    final openingCash = _summary!['opening_cash'] as double;
    final totalOrders = _summary!['total_orders'] as int;
    final totalRevenue = _summary!['total_revenue'] as double;
    final cashSales = _summary!['total_cash_sales'] as double;
    final cardSales = _summary!['total_card_sales'] as double;
    final cashIn = _summary!['total_cash_in'] as double;
    final cashOut = _summary!['total_cash_out'] as double;
    final expectedCash = _summary!['expected_cash'] as double;

    final countedCash = double.tryParse(_cashCountCtrl.text.replaceAll('\$', '').trim()) ?? 0.0;
    final countedCard = double.tryParse(_cardCountCtrl.text.replaceAll('\$', '').trim()) ?? 0.0;

    final cashDiff = countedCash - expectedCash;
    final cardDiff = countedCard - cardSales;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Header with Order count & Total Revenue
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.lock_rounded, size: 20, color: Color(0xFF7C3AED)),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Closing Register',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$totalOrders orders: \$ ${totalRevenue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 1. CASH SECTION
              _buildSectionTitle('Cash'),
              const SizedBox(height: 6),
              _buildRow('Opening', '\$ ${openingCash.toStringAsFixed(2)}'),
              _buildRow('Payments in Cash', '\$ ${cashSales.toStringAsFixed(2)}'),
              _buildRow('▸ Cash In / Out', '\$ ${(cashIn - cashOut).toStringAsFixed(2)}'),
              _buildRow('Counted', '\$ ${countedCash.toStringAsFixed(2)}', isBold: true),
              _buildRow(
                'Difference',
                cashDiff == 0
                    ? '\$ 0.00'
                    : (cashDiff > 0
                          ? '+ \$ ${cashDiff.toStringAsFixed(2)}'
                          : '- \$ ${cashDiff.abs().toStringAsFixed(2)}'),
                isBold: true,
                diffColor: cashDiff == 0
                    ? const Color(0xFF059669)
                    : (cashDiff < 0 ? const Color(0xFFDC2626) : const Color(0xFF0284C7)),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // 2. CARD SECTION
              _buildSectionTitle('Card'),
              const SizedBox(height: 6),
              _buildRow('Counted', '\$ ${countedCard.toStringAsFixed(2)}'),
              _buildRow(
                'Difference',
                cardDiff == 0 ? '\$ 0.00' : '\$ ${cardDiff.toStringAsFixed(2)}',
                diffColor: cardDiff == 0 ? const Color(0xFF059669) : const Color(0xFFDC2626),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // 3. CUSTOMER ACCOUNT SECTION
              _buildSectionTitle('Customer Account'),
              const SizedBox(height: 6),
              _buildRow('Counted', '\$ 0.00'),
              _buildRow('Difference', '\$ 0.00', diffColor: const Color(0xFF059669)),
              const SizedBox(height: 16),
              const Divider(thickness: 1.5),
              const SizedBox(height: 16),

              // 4. CASH COUNT & CARD COUNT INPUTS
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Cash Count',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                            InkWell(
                              onTap: () async {
                                final result = await DualCurrencyPieceCounterDialog.show(
                                  context,
                                  title: 'Closing Cash Piece Counter (USD & KHR)',
                                );
                                if (result != null) {
                                  setState(() {
                                    _cashCountCtrl.text = result.combinedUsd.toStringAsFixed(2);
                                    if (_closingNoteCtrl.text.isEmpty) {
                                      _closingNoteCtrl.text = result.summaryText;
                                    } else {
                                      _closingNoteCtrl.text += '\n\n${result.summaryText}';
                                    }
                                  });
                                }
                              },
                              child: const Row(
                                children: [
                                  AppSvgIcon.sprite(SpriteIcons.calculator, size: 14, color: Color(0xFF7C3AED)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Piece Counter',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _cashCountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            suffixIcon: IconButton(
                              icon: const AppSvgIcon(AssetTheme.close, size: 16, color: Color(0xFF64748B)),
                              onPressed: () => setState(() => _cashCountCtrl.clear()),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Card Count',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _cardCountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            suffixIcon: IconButton(
                              icon: const AppSvgIcon(AssetTheme.close, size: 16, color: Color(0xFF64748B)),
                              onPressed: () => setState(() => _cardCountCtrl.clear()),
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5. OPENING NOTE RECAP & CLOSING NOTE
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Opening note',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            activeSession?.openingNotes ?? 'No opening notes recorded.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Closing note',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _closingNoteCtrl,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Add a closing note...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 6. ACTION BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF714B67),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final success = await reg.closeRegister(
                            closingCashCounted: countedCash,
                            closingCardCounted: countedCard,
                            closingNotes: _closingNoteCtrl.text.trim(),
                          );

                          if (success && context.mounted) {
                            // Auto-print the closing report
                            await _printDailySaleReport();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Register session closed and reconciled successfully!'),
                                  backgroundColor: Color(0xFF059669),
                                ),
                              );
                              Navigator.of(context).pop(true);
                            }
                          }
                        },
                        icon: const Icon(Icons.lock_rounded, size: 16),
                        label: const Text('Close Register', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Discard', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await CashInOutDialog.show(context);
                          _loadData();
                        },
                        child: const Text(
                          'Cash In/Out',
                          style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        onPressed: _isPrinting ? null : _printDailySaleReport,
                        icon: _isPrinting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print Report', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? diffColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: diffColor ?? (isBold ? const Color(0xFF0F172A) : const Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }
}
