import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/register_controller.dart';
import '../../models/register_session_model.dart';
import '../../core/theme/asset_theme.dart';
import '../../widgets/app_svg_icon.dart';

class OpenRegisterDialog extends StatefulWidget {
  const OpenRegisterDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const OpenRegisterDialog(),
    );
  }

  @override
  State<OpenRegisterDialog> createState() => _OpenRegisterDialogState();
}

class _OpenRegisterDialogState extends State<OpenRegisterDialog> {
  final TextEditingController _cashCtrl = TextEditingController(text: '345.00');
  final TextEditingController _notesCtrl = TextEditingController(
    text: 'Opening details:\n  1 x \$ 5.00\n  2 x \$ 20.00\n  1 x \$ 100.00\n  1 x \$ 200.00\nTotal: \$ 345.00',
  );

  bool _showDenominationWizard = false;

  final List<DenominationItem> _denominations = [
    DenominationItem(value: 200.0, label: '\$200 Note', count: 1),
    DenominationItem(value: 100.0, label: '\$100 Note', count: 1),
    DenominationItem(value: 50.0, label: '\$50 Note', count: 0),
    DenominationItem(value: 20.0, label: '\$20 Note', count: 2),
    DenominationItem(value: 10.0, label: '\$10 Note', count: 0),
    DenominationItem(value: 5.0, label: '\$5 Note', count: 1),
    DenominationItem(value: 1.0, label: '\$1 Coin/Bill', count: 0),
    DenominationItem(value: 0.25, label: '25¢ Coin', count: 0),
  ];

  void _recalcFromDenominations() {
    double total = 0.0;
    final buffer = StringBuffer('Opening details:\n');

    for (var d in _denominations) {
      if (d.count > 0) {
        total += d.total;
        buffer.writeln('  ${d.count} x \$ ${d.value.toStringAsFixed(2)}');
      }
    }
    buffer.write('Total: \$ ${total.toStringAsFixed(2)}');

    setState(() {
      _cashCtrl.text = total.toStringAsFixed(2);
      _notesCtrl.text = buffer.toString();
    });
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _notesCtrl.dispose();
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
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Opening Control',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(AssetTheme.close, size: 18, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Opening Cash Input Field
              const Text(
                'Opening cash',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cashCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        suffixIcon: IconButton(
                          icon: const AppSvgIcon(AssetTheme.close, size: 16, color: Color(0xFF64748B)),
                          onPressed: () => setState(() => _cashCtrl.clear()),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bill / Denomination Calculator Trigger Button
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showDenominationWizard = !_showDenominationWizard;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: _showDenominationWizard ? const Color(0xFF7C3AED) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Center(
                        child: AppSvgIcon(
                          AssetTheme.payment,
                          color: _showDenominationWizard ? Colors.white : const Color(0xFF475569),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Denomination breakdown expansion if active
              if (_showDenominationWizard) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Count Denominations (Bills & Coins)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _denominations.map((d) {
                          return Container(
                            width: 140,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    d.label,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                DropdownButton<int>(
                                  value: d.count,
                                  isDense: true,
                                  underline: const SizedBox(),
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                  items: List.generate(21, (i) => DropdownMenuItem(value: i, child: Text('$i'))),
                                  onChanged: (val) {
                                    if (val != null) {
                                      d.count = val;
                                      _recalcFromDenominations();
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Opening Note Input Field
              const Text(
                'Opening note',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtrl,
                maxLines: 4,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'Add an opening note...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF714B67), // Odoo Purple Accent
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final amount = double.tryParse(_cashCtrl.text.replaceAll('\$', '').trim()) ?? 0.0;
                      await register.openRegister(
                        openingCash: amount,
                        openingNotes: _notesCtrl.text.trim(),
                        branchId: auth.currentBranchId,
                        branchName: auth.currentBranchName,
                        cashierId: auth.currentUser.id,
                        cashierName: auth.currentUser.displayName,
                        kickDrawer: true,
                      );

                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    child: const Text('Open Register', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ),
    );
  }
}
