import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../controllers/settings_controller.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../core/theme/sprite_icons.dart';
import '../../../widgets/app_svg_icon.dart';

class PieceCountResult {
  final double totalUsd;
  final double totalKhr;
  final double combinedUsd;
  final String summaryText;

  const PieceCountResult({
    required this.totalUsd,
    required this.totalKhr,
    required this.combinedUsd,
    required this.summaryText,
  });
}

class _BanknoteDenomination {
  final double value;
  final String label;
  final bool isKhr;
  int count = 0;

  _BanknoteDenomination({
    required this.value,
    required this.label,
    required this.isKhr,
  });

  double get subtotal => value * count;
}

class DualCurrencyPieceCounterDialog extends StatefulWidget {
  final String title;

  const DualCurrencyPieceCounterDialog({
    super.key,
    this.title = 'Banknote Piece Counter (USD & KHR)',
  });

  static Future<PieceCountResult?> show(BuildContext context, {String? title}) {
    return showDialog<PieceCountResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => DualCurrencyPieceCounterDialog(
        title: title ?? 'Banknote Piece Counter (USD & KHR)',
      ),
    );
  }

  @override
  State<DualCurrencyPieceCounterDialog> createState() =>
      _DualCurrencyPieceCounterDialogState();
}

class _DualCurrencyPieceCounterDialogState
    extends State<DualCurrencyPieceCounterDialog> {
  late final List<_BanknoteDenomination> _usdNotes;
  late final List<_BanknoteDenomination> _khrNotes;

  @override
  void initState() {
    super.initState();
    _usdNotes = [
      _BanknoteDenomination(value: 100.0, label: '\$100', isKhr: false),
      _BanknoteDenomination(value: 50.0, label: '\$50', isKhr: false),
      _BanknoteDenomination(value: 20.0, label: '\$20', isKhr: false),
      _BanknoteDenomination(value: 10.0, label: '\$10', isKhr: false),
      _BanknoteDenomination(value: 5.0, label: '\$5', isKhr: false),
      _BanknoteDenomination(value: 1.0, label: '\$1', isKhr: false),
    ];

    _khrNotes = [
      _BanknoteDenomination(value: 100000.0, label: '100,000 ៛', isKhr: true),
      _BanknoteDenomination(value: 50000.0, label: '50,000 ៛', isKhr: true),
      _BanknoteDenomination(value: 20000.0, label: '20,000 ៛', isKhr: true),
      _BanknoteDenomination(value: 15000.0, label: '15,000 ៛', isKhr: true),
      _BanknoteDenomination(value: 10000.0, label: '10,000 ៛', isKhr: true),
      _BanknoteDenomination(value: 5000.0, label: '5,000 ៛', isKhr: true),
      _BanknoteDenomination(value: 2000.0, label: '2,000 ៛', isKhr: true),
      _BanknoteDenomination(value: 1000.0, label: '1,000 ៛', isKhr: true),
      _BanknoteDenomination(value: 500.0, label: '500 ៛', isKhr: true),
      _BanknoteDenomination(value: 100.0, label: '100 ៛', isKhr: true),
    ];
  }

  double get _totalUsd =>
      _usdNotes.fold(0.0, (sum, item) => sum + item.subtotal);
  double get _totalKhr =>
      _khrNotes.fold(0.0, (sum, item) => sum + item.subtotal);

  double _combinedUsd(double rate) {
    if (rate <= 0) return _totalUsd;
    return _totalUsd + (_totalKhr / rate);
  }

  String _buildSummary(double rate) {
    final buffer = StringBuffer('Money Count Details:\n');
    if (_totalUsd > 0) {
      buffer.writeln('USD (\$):');
      for (final n in _usdNotes) {
        if (n.count > 0) {
          buffer.writeln(
            '  ${n.count} x ${n.label} = \$${n.subtotal.toStringAsFixed(2)}',
          );
        }
      }
      buffer.writeln('  Subtotal USD: \$${_totalUsd.toStringAsFixed(2)}');
    }
    if (_totalKhr > 0) {
      buffer.writeln('KHR (៛):');
      final fmt = NumberFormat('#,###');
      for (final n in _khrNotes) {
        if (n.count > 0) {
          buffer.writeln(
            '  ${n.count} x ${n.label} = ${fmt.format(n.subtotal)} ៛',
          );
        }
      }
      buffer.writeln(
        '  Subtotal KHR: ${fmt.format(_totalKhr)} ៛ (≈ \$${(_totalKhr / rate).toStringAsFixed(2)})',
      );
    }
    buffer.write('Combined Total: \$${_combinedUsd(rate).toStringAsFixed(2)}');
    return buffer.toString();
  }

  void _clearAll() {
    setState(() {
      for (final n in _usdNotes) {
        n.count = 0;
      }
      for (final n in _khrNotes) {
        n.count = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final rate = settings.usdToKhrRate > 0 ? settings.usdToKhrRate : 4000.0;
    final combined = _combinedUsd(rate);
    final khrFmt = NumberFormat('#,###');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const AppSvgIcon(
                          AssetTheme.payment,
                          size: 20,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _clearAll,
                        icon: const AppSvgIcon.sprite(
                          SpriteIcons.refresh,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        label: const Text('Clear All'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                        ),
                      ),
                      IconButton(
                        icon: const AppSvgIcon(
                          AssetTheme.close,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Rate Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Rate: \$1.00 = ${khrFmt.format(rate)} KHR',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'USD: \$${_totalUsd.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'KHR: ${khrFmt.format(_totalKhr)} ៛',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Side-by-Side 2 Columns (USD & KHR)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: USD Column
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '💵 USD Banknotes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '\$${_totalUsd.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _usdNotes.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (ctx, i) =>
                                    _buildDenominationRow(_usdNotes[i]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Right: KHR Column
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '🇰🇭 KHR Banknotes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${khrFmt.format(_totalKhr)} ៛',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _khrNotes.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (ctx, i) =>
                                    _buildDenominationRow(_khrNotes[i]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Combined Total Summary & Action Buttons
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Combined Counted Total:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${combined.toStringAsFixed(2)}  (${khrFmt.format((combined * rate).round())} KHR)',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF714B67,
                        ), // Odoo Aubergine
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
                      onPressed: () {
                        final result = PieceCountResult(
                          totalUsd: _totalUsd,
                          totalKhr: _totalKhr,
                          combinedUsd: combined,
                          summaryText: _buildSummary(rate),
                        );
                        Navigator.of(context).pop(result);
                      },
                      icon: const AppSvgIcon.sprite(
                        SpriteIcons.check,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Apply Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDenominationRow(_BanknoteDenomination item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Label
          SizedBox(
            width: 76,
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const Spacer(),

          // Stepper: [-] [count] [+]
          IconButton(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            icon: const AppSvgIcon.sprite(
              SpriteIcons.minus,
              size: 16,
              color: Color(0xFF64748B),
            ),
            onPressed: item.count > 0
                ? () => setState(() => item.count--)
                : null,
          ),
          Container(
            width: 38,
            alignment: Alignment.center,
            child: Text(
              '${item.count}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: item.count > 0
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            icon: const AppSvgIcon.sprite(
              SpriteIcons.plus,
              size: 16,
              color: Color(0xFF7C3AED),
            ),
            onPressed: () => setState(() => item.count++),
          ),
        ],
      ),
    );
  }
}
