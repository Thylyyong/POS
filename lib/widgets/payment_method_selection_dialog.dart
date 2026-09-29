import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Modal dialog allowing cashier to choose payment method (Cash vs ABA KHQR),
/// showing dual currency totals (USD & KHR) as requested.
class PaymentMethodSelectionDialog extends StatelessWidget {
  final String orderNumber;
  final double totalAmountUsd;
  final int totalAmountKhr;
  final VoidCallback onSelectCash;
  final VoidCallback onSelectAbaKhqr;

  const PaymentMethodSelectionDialog({
    super.key,
    required this.orderNumber,
    required this.totalAmountUsd,
    required this.totalAmountKhr,
    required this.onSelectCash,
    required this.onSelectAbaKhqr,
  });

  static Future<void> show(
    BuildContext context, {
    required String orderNumber,
    required double totalAmountUsd,
    required int totalAmountKhr,
    required VoidCallback onSelectCash,
    required VoidCallback onSelectAbaKhqr,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PaymentMethodSelectionDialog(
        orderNumber: orderNumber,
        totalAmountUsd: totalAmountUsd,
        totalAmountKhr: totalAmountKhr,
        onSelectCash: onSelectCash,
        onSelectAbaKhqr: onSelectAbaKhqr,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedKhr = NumberFormat('#,###').format(totalAmountKhr);
    final displayOrderNum = orderNumber.isNotEmpty
        ? (orderNumber.startsWith('#') ? orderNumber : '#$orderNumber')
        : '#0011';

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header: Title & Close Button ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment for Order $displayOrderNum',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Select payment method to continue',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Total Due Card (USD & KHR Dual Currency) ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
                ),
                child: Row(
                  children: [
                    // USD Total Due
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL DUE (USD)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D9488),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '\$${totalAmountUsd.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F766E),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Vertical Divider Line
                    Container(
                      width: 1,
                      height: 38,
                      color: const Color(0xFFA7F3D0),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                    ),

                    // KHR Total Due
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL DUE (KHR)',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D9488),
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '៛$formattedKhr',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Payment Selection Cards: Cash vs ABA KHQR ──
              Row(
                children: [
                  // 1. Cash Payment Card
                  Expanded(
                    child: _PaymentOptionCard(
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectCash();
                      },
                      iconWidget: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '\$',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      title: 'Cash',
                      subtitle: 'USD / KHR',
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 2. ABA KHQR Payment Card
                  Expanded(
                    child: _PaymentOptionCard(
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelectAbaKhqr();
                      },
                      iconWidget: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Navy top header with "ABA"
                            Expanded(
                              flex: 11,
                              child: Container(
                                color: const Color(0xFF003853),
                                alignment: Alignment.center,
                                child: const Text(
                                  'ABA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                            // Red bottom ribbon with "KHQR"
                            Expanded(
                              flex: 8,
                              child: Container(
                                color: const Color(0xFFD41A22),
                                alignment: Alignment.center,
                                child: const Text(
                                  'KHQR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9.5,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: 'ABA KHQR',
                      subtitle: 'Scan & Pay',
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
}

class _PaymentOptionCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget iconWidget;
  final String title;
  final String subtitle;

  const _PaymentOptionCard({
    required this.onTap,
    required this.iconWidget,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_PaymentOptionCard> createState() => _PaymentOptionCardState();
}

class _PaymentOptionCardState extends State<_PaymentOptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFF8FAFC) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0xFF0D9488).withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: _isHovered ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              widget.iconWidget,
              const SizedBox(height: 14),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
