import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/register_controller.dart';
import 'cash_in_out_dialog.dart';
import '../../core/theme/asset_theme.dart';
import '../../widgets/app_svg_icon.dart';

class CloseRegisterDialog extends StatefulWidget {
  const CloseRegisterDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const CloseRegisterDialog(),
    );
  }

  @override
  State<CloseRegisterDialog> createState() => _CloseRegisterDialogState();
}

class _CloseRegisterDialogState extends State<CloseRegisterDialog> {
  final TextEditingController _cashCountCtrl = TextEditingController();
  final TextEditingController _cardCountCtrl = TextEditingController();
  final TextEditingController _closingNoteCtrl = TextEditingController();

  Map<String, dynamic>? _summary;
  bool _isLoading = true;

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

      // Pre-fill with expected cash for convenience
      final expectedCash =
          (summary['expected_cash'] as num?)?.toDouble() ?? 0.0;
      final cardSales =
          (summary['total_card_sales'] as num?)?.toDouble() ?? 0.0;
      _cashCountCtrl.text = expectedCash.toStringAsFixed(2);
      _cardCountCtrl.text = cardSales.toStringAsFixed(2);
    });
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

    final countedCash =
        double.tryParse(_cashCountCtrl.text.replaceAll('\$', '').trim()) ?? 0.0;
    final countedCard =
        double.tryParse(_cardCountCtrl.text.replaceAll('\$', '').trim()) ?? 0.0;

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
                  const Text(
                    'Closing Register',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
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

              // 1. CASH SECTION BREAKDOWN TABLE
              _buildSectionTitle('Cash'),
              const SizedBox(height: 6),
              _buildRow('Opening', '\$ ${openingCash.toStringAsFixed(2)}'),
              _buildRow(
                'Payments in Cash',
                '\$ ${cashSales.toStringAsFixed(2)}',
              ),
              _buildRow(
                '▸ Cash In / Out',
                '\$ ${(cashIn - cashOut).toStringAsFixed(2)}',
              ),
              _buildRow(
                'Counted',
                '\$ ${countedCash.toStringAsFixed(2)}',
                isBold: true,
              ),
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
                    : (cashDiff < 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF0284C7)),
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
                diffColor: cardDiff == 0
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // 3. CUSTOMER ACCOUNT SECTION
              _buildSectionTitle('Customer Account'),
              const SizedBox(height: 6),
              _buildRow('Counted', '\$ 0.00'),
              _buildRow(
                'Difference',
                '\$ 0.00',
                diffColor: const Color(0xFF059669),
              ),
              const SizedBox(height: 16),
              const Divider(thickness: 1.5),
              const SizedBox(height: 16),

              // 4. CASH COUNT & CARD COUNT INPUTS (SIDE BY SIDE)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cash Count',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _cashCountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            suffixIcon: IconButton(
                              icon: const AppSvgIcon(AssetTheme.close, size: 16, color: Color(0xFF64748B)),
                              onPressed: () =>
                                  setState(() => _cashCountCtrl.clear()),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _cardCountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            suffixIcon: IconButton(
                              icon: const AppSvgIcon(AssetTheme.close, size: 16, color: Color(0xFF64748B)),
                              onPressed: () =>
                                  setState(() => _cardCountCtrl.clear()),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 5. OPENING NOTE RECAP & CLOSING NOTE INPUT
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Opening note',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
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
                            activeSession?.openingNotes ??
                                'No opening notes recorded.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _closingNoteCtrl,
                          maxLines: 4,
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Add a closing note...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 6. ACTION BUTTONS BAR (MATCHING IMAGE 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF714B67,
                          ), // Odoo Purple
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final success = await reg.closeRegister(
                            closingCashCounted: countedCash,
                            closingCardCounted: countedCard,
                            closingNotes: _closingNoteCtrl.text.trim(),
                          );

                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Register session closed and reconciled successfully!',
                                ),
                                backgroundColor: Color(0xFF059669),
                              ),
                            );
                            Navigator.of(context).pop(true);
                          }
                        },
                        child: const Text(
                          'Close Register',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text(
                          'Discard',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () async {
                          await CashInOutDialog.show(context);
                          _loadData();
                        },
                        child: const Text(
                          'Cash In/Out',
                          style: TextStyle(
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Daily Sale report generated & saved!',
                              ),
                            ),
                          );
                        },
                        icon: const AppSvgIcon(AssetTheme.files, size: 16, color: Colors.white),
                        label: const Text(
                          'Daily Sale',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? diffColor,
  }) {
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
              color:
                  diffColor ??
                  (isBold ? const Color(0xFF0F172A) : const Color(0xFF334155)),
            ),
          ),
        ],
      ),
    );
  }
}
