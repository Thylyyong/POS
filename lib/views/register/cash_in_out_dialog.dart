import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/register_controller.dart';
import '../../core/theme/asset_theme.dart';
import '../../models/cash_movement_model.dart';
import '../../widgets/app_svg_icon.dart';

class CashInOutDialog extends StatefulWidget {
  final CashMovementType initialType;

  const CashInOutDialog({super.key, this.initialType = CashMovementType.cashIn});

  static Future<bool?> show(BuildContext context, {CashMovementType initialType = CashMovementType.cashIn}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CashInOutDialog(initialType: initialType),
    );
  }

  @override
  State<CashInOutDialog> createState() => _CashInOutDialogState();
}

class _CashInOutDialogState extends State<CashInOutDialog> {
  late CashMovementType _selectedType;
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();

  final List<String> _quickReasonsIn = [
    'Add Float / Change',
    'Petty Cash Deposit',
    'Opening Cash Adjustment',
    'Other Cash In',
  ];

  final List<String> _quickReasonsOut = [
    'Mid-day Safe Drop',
    'Supplier / Delivery Payout',
    'Staff Expense / Grocery',
    'Owner Draw / Withdrawal',
    'Other Cash Out',
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final register = context.read<RegisterController>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cash In / Out Adjustment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                IconButton(
                  icon: const AppSvgIcon(AssetTheme.close, size: 18, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Type Selector Segment (Cash In vs Cash Out)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedType = CashMovementType.cashIn),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedType == CashMovementType.cashIn ? const Color(0xFF059669) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppSvgIcon(
                              AssetTheme.plus,
                              size: 13,
                              color: _selectedType == CashMovementType.cashIn ? Colors.white : const Color(0xFF059669),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Cash In (Put In)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedType == CashMovementType.cashIn ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedType = CashMovementType.cashOut),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedType == CashMovementType.cashOut ? const Color(0xFFDC2626) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppSvgIcon(
                              AssetTheme.minus,
                              size: 13,
                              color: _selectedType == CashMovementType.cashOut ? Colors.white : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Cash Out (Take Out)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedType == CashMovementType.cashOut ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount Input Field
            const Text(
              'Amount',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Reason / Notes Input Field
            const Text(
              'Reason / Description',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter reason for cash movement...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Reasons Pills
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (_selectedType == CashMovementType.cashIn ? _quickReasonsIn : _quickReasonsOut).map((reason) {
                return InkWell(
                  onTap: () => setState(() => _reasonCtrl.text = reason),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      reason,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedType == CashMovementType.cashIn ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final amount = double.tryParse(_amountCtrl.text.replaceAll('\$', '').trim()) ?? 0.0;
                    if (amount <= 0) return;

                    final reason = _reasonCtrl.text.trim().isEmpty ? 'General Adjustment' : _reasonCtrl.text.trim();

                    await register.addCashMovement(
                      type: _selectedType,
                      amount: amount,
                      reason: reason,
                      authorizedById: auth.currentUser.id,
                      authorizedByName: auth.currentUser.displayName,
                      kickDrawer: true,
                    );

                    if (context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: Text('Confirm ${_selectedType.displayName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Discard', style: TextStyle(color: Color(0xFF64748B))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
