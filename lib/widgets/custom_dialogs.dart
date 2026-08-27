import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_config.dart';

class CashPaymentDialog extends StatefulWidget {
  final double totalAmount;
  final String currencySymbol;
  final ValueChanged<double>? onConfirmPayment;

  const CashPaymentDialog({
    super.key,
    required this.totalAmount,
    required this.currencySymbol,
    this.onConfirmPayment,
  });

  @override
  State<CashPaymentDialog> createState() => _CashPaymentDialogState();
}

class _CashPaymentDialogState extends State<CashPaymentDialog> {
  String _tenderedInput = '';
  double get _tenderedAmount => double.tryParse(_tenderedInput) ?? 0.0;
  double get _changeAmount => (_tenderedAmount - widget.totalAmount).clamp(0.0, double.infinity);
  bool get _isExactOrOver => _tenderedAmount >= widget.totalAmount - 0.001;

  @override
  void initState() {
    super.initState();
    _tenderedInput = widget.totalAmount.toStringAsFixed(2);
  }

  void _addQuickTender(double amount) {
    setState(() {
      _tenderedInput = amount.toStringAsFixed(2);
    });
  }

  void _appendDigit(String digit) {
    setState(() {
      if (digit == '.' && _tenderedInput.contains('.')) return;
      if (_tenderedInput == '0' && digit != '.') {
        _tenderedInput = digit;
      } else {
        _tenderedInput += digit;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_tenderedInput.isNotEmpty) {
        _tenderedInput = _tenderedInput.substring(0, _tenderedInput.length - 1);
      }
    });
  }

  void _clear() {
    setState(() {
      _tenderedInput = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.currencySymbol;
    final total = widget.totalAmount;
    final List<double> quickDenominations = {
      total,
      if (total < 5) 5.0,
      if (total < 10) 10.0,
      if (total < 20) 20.0,
      if (total < 50) 50.0,
      if (total < 100) 100.0,
      if (total >= 100) ...[
        (total / 50).ceil() * 50.0,
        (total / 100).ceil() * 100.0,
        ((total / 100).ceil() + 1) * 100.0,
      ],
    }.toList()..sort();

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.payments, color: AppConfig.accentGreen, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Cash Payment & Change',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(null);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total Due vs Change Calculation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TOTAL DUE', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '$currency${widget.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 40, width: 1, color: const Color(0xFFCBD5E1)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CHANGE DUE', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '$currency${_changeAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _isExactOrOver ? AppConfig.accentGreenDark : AppConfig.accentRose,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick Amount Suggestion Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: quickDenominations.map((amount) {
                    final isExact = (amount - widget.totalAmount).abs() < 0.01;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: isExact ? AppConfig.accentGreen.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                        side: BorderSide(color: isExact ? AppConfig.accentGreen : const Color(0xFFCBD5E1)),
                        label: Text(
                          isExact ? 'Exact ($currency${amount.toStringAsFixed(2)})' : '$currency${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isExact ? AppConfig.accentGreenDark : const Color(0xFF334155),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => _addQuickTender(amount),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Tendered Input Display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isExactOrOver ? AppConfig.accentGreen : AppConfig.accentRose,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Cash Tendered:', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                    Text(
                      _tenderedInput.isEmpty ? '$currency 0.00' : '$currency $_tenderedInput',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Numpad Grid
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.55,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildNumKey('1'),
                  _buildNumKey('2'),
                  _buildNumKey('3'),
                  _buildActionKey('C', _clear, color: AppConfig.accentRose),
                  _buildNumKey('4'),
                  _buildNumKey('5'),
                  _buildNumKey('6'),
                  _buildActionKey('⌫', _backspace, color: AppConfig.accentAmber),
                  _buildNumKey('7'),
                  _buildNumKey('8'),
                  _buildNumKey('9'),
                  _buildNumKey('00'),
                  _buildNumKey('.'),
                  _buildNumKey('0'),
                  _buildNumKey('50'),
                  _buildNumKey('100'),
                ],
              ),
              const SizedBox(height: 20),

              // Complete Payment Button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isExactOrOver ? AppConfig.accentGreen : const Color(0xFFCBD5E1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isExactOrOver
                      ? () {
                          widget.onConfirmPayment?.call(_tenderedAmount);
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop(_tenderedAmount);
                          }
                        }
                      : null,
                  icon: const Icon(Icons.check_circle, size: 22),
                  label: Text(
                    _isExactOrOver
                        ? 'Complete Cash Sale ($currency${_tenderedAmount.toStringAsFixed(2)})'
                        : 'Amount Less Than Total Due',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumKey(String label) {
    return InkWell(
      onTap: () => _appendDigit(label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ),
    );
  }

  Widget _buildActionKey(String label, VoidCallback onTap, {required Color color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}

class QrPaymentDialog extends StatefulWidget {
  final double totalAmount;
  final String currencySymbol;
  final String qrPayload;
  final VoidCallback? onPaymentConfirmed;

  const QrPaymentDialog({
    super.key,
    required this.totalAmount,
    required this.currencySymbol,
    required this.qrPayload,
    this.onPaymentConfirmed,
  });

  @override
  State<QrPaymentDialog> createState() => _QrPaymentDialogState();
}

class _QrPaymentDialogState extends State<QrPaymentDialog> {
  int _secondsRemaining = 120;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.currencySymbol;
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_2, color: AppConfig.accentCyan, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Customer QR Payment',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(false);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Display Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL DUE:', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    '$currency${widget.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConfig.accentGreenDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // High-Resolution Dynamic QR Code Container
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppConfig.accentCyan.withValues(alpha: 0.18),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: QrImageView(
                  data: widget.qrPayload,
                  version: QrVersions.auto,
                  size: 190.0,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Countdown Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined, color: AppConfig.accentAmber, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Expires in $minutes:$seconds',
                  style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Confirm Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConfig.accentGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  widget.onPaymentConfirmed?.call();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(true);
                  }
                },
                icon: const Icon(Icons.done_all, size: 22),
                label: const Text(
                  'Confirm Payment Received',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
