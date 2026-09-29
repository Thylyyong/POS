import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/settings_controller.dart';
import '../models/models.dart';
import '../services/aba_payment_service.dart';
import 'aba_khqr_card.dart';

enum AbaPaymentDialogState {
  waiting,
  checking,
  success,
  expired,
  failed,
}

/// Production-ready Modal Dialog for ABA PAY KHQR dynamic payments.
///
/// Features:
/// - Renders dynamic raw EMVCo KHQR code with official ABA styling.
/// - Live countdown timer (3 minutes default).
/// - Non-blocking background polling (every 2.5s) checking backend status.
/// - Overlap prevention: Ensures slow network requests don't pile up.
/// - Memory-safe: Cancels all timers on `dispose()`.
/// - Clean callbacks: `onSuccess`, `onTimeout`, `onCancel`.
class AbaKhqrDialog extends StatefulWidget {
  /// The transaction ID associated with this payment
  final String tranId;

  /// The raw EMVCo KHQR payload string from backend
  final String qrString;

  /// Payment amount
  final double amount;

  /// Currency code ('USD' or 'KHR')
  final String currency;

  /// Store/Merchant name shown on the KHQR card
  final String? storeName;

  /// Optional USD to KHR conversion rate (defaults to 4000.0 or from Settings)
  final double? usdToKhrRate;

  /// Total countdown duration in seconds (default: 180 = 3 minutes)
  final int timeoutSeconds;

  /// Polling interval for verification checks (default: 2.5 seconds)
  final Duration pollInterval;

  /// Service instance to use for API calls
  final AbaPaymentService? paymentService;

  /// Callback when payment is successfully confirmed (code "0")
  final ValueChanged<String> onSuccess;

  /// Callback when the 3-minute payment window times out
  final VoidCallback? onTimeout;

  /// Callback when cashier cancels or closes the dialog
  final VoidCallback? onCancel;

  const AbaKhqrDialog({
    super.key,
    required this.tranId,
    required this.qrString,
    required this.amount,
    this.currency = 'USD',
    this.storeName,
    this.usdToKhrRate,
    this.timeoutSeconds = 180,
    this.pollInterval = const Duration(milliseconds: 2500),
    this.paymentService,
    required this.onSuccess,
    this.onTimeout,
    this.onCancel,
  });

  /// Convenient static helper to show the dialog
  static Future<bool?> show(
    BuildContext context, {
    required String tranId,
    required String qrString,
    required double amount,
    String currency = 'USD',
    String? storeName,
    double? usdToKhrRate,
    int timeoutSeconds = 180,
    Duration pollInterval = const Duration(milliseconds: 2500),
    AbaPaymentService? paymentService,
    required ValueChanged<String> onSuccess,
    VoidCallback? onTimeout,
    VoidCallback? onCancel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AbaKhqrDialog(
        tranId: tranId,
        qrString: qrString,
        amount: amount,
        currency: currency,
        storeName: storeName,
        usdToKhrRate: usdToKhrRate,
        timeoutSeconds: timeoutSeconds,
        pollInterval: pollInterval,
        paymentService: paymentService,
        onSuccess: onSuccess,
        onTimeout: onTimeout,
        onCancel: onCancel,
      ),
    );
  }

  @override
  State<AbaKhqrDialog> createState() => _AbaKhqrDialogState();
}

class _AbaKhqrDialogState extends State<AbaKhqrDialog>
    with SingleTickerProviderStateMixin {
  late int _secondsRemaining;
  Timer? _countdownTimer;
  Timer? _pollingTimer;

  bool _isChecking = false;
  AbaPaymentDialogState _dialogState = AbaPaymentDialogState.waiting;
  String? _statusMessage;
  int _consecutiveFailures = 0;

  late final AbaPaymentService _paymentService;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.timeoutSeconds;
    _paymentService = widget.paymentService ?? AbaPaymentService.instance;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    _stopTimers();
    _pulseController.dispose();
    super.dispose();
  }

  void _stopTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        setState(() {
          _secondsRemaining = 0;
          _dialogState = AbaPaymentDialogState.expired;
        });
        _stopTimers();
        widget.onTimeout?.call();
      }
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(widget.pollInterval, (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    // Prevent overlapping network calls if the network is sluggish
    if (_isChecking || !mounted || _dialogState == AbaPaymentDialogState.success) {
      return;
    }

    _isChecking = true;

    try {
      final response = await _paymentService.checkStatus(tranId: widget.tranId);

      if (!mounted) return;

      if (response.isSuccess) {
        _stopTimers();
        setState(() {
          _dialogState = AbaPaymentDialogState.success;
          _statusMessage = response.message.isNotEmpty
              ? response.message
              : 'Payment Approved!';
        });

        // Provide satisfying visual confirmation before closing dialog
        await Future.delayed(const Duration(milliseconds: 700));

        if (!mounted) return;
        widget.onSuccess(widget.tranId);
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      } else if (response.isPending) {
        _consecutiveFailures = 0;
        if (_dialogState != AbaPaymentDialogState.waiting) {
          setState(() {
            _dialogState = AbaPaymentDialogState.waiting;
            _statusMessage = null;
          });
        }
      } else {
        // Declined or failed status from backend
        if (response.isFailed) {
          setState(() {
            _statusMessage = response.message.isNotEmpty
                ? response.message
                : 'Payment unconfirmed';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      _consecutiveFailures++;
      // Only display connection warning if multiple consecutive requests fail
      if (_consecutiveFailures >= 3 && _dialogState == AbaPaymentDialogState.waiting) {
        setState(() {
          _statusMessage = 'Verifying network connection...';
        });
      }
    } finally {
      _isChecking = false;
    }
  }

  void _handleCancel() {
    _stopTimers();
    widget.onCancel?.call();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve store settings for fallback merchant name & exchange rate
    StoreSettingsModel? settings;
    try {
      settings = context.read<SettingsController>().settings;
    } catch (_) {}

    final effectiveStoreName = widget.storeName?.isNotEmpty == true
        ? widget.storeName!
        : (settings?.storeName.isNotEmpty == true
            ? settings!.storeName
            : 'CA SOLUTION POS');

    final rate = widget.usdToKhrRate ?? (settings?.usdToKhrRate ?? 4000.0);
    final isUsd = widget.currency.toUpperCase() == 'USD';
    final khrAmount = isUsd
        ? (widget.amount * rate).round()
        : widget.amount.round();

    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');
    final isLowTime = _secondsRemaining <= 30 && _secondsRemaining > 0;

    return Dialog(
      backgroundColor: Colors.white,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 390,
          maxHeight: MediaQuery.of(context).size.height * 0.94,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header: Title, TranId Badge, and Close Button ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 20,
                              color: Color(0xFF005A70),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'ABA PAY KHQR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ref: #${widget.tranId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: Color(0xFF64748B)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                    onPressed: _handleCancel,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Official ABA PAY KHQR Card with Dynamic Raw Payload ──
              Center(
                child: AbaKhqrCard(
                  storeName: effectiveStoreName,
                  amount: widget.amount,
                  khrAmount: khrAmount,
                  currencySymbol: isUsd ? '\$' : '៛',
                  qrData: widget.qrString,
                  qrSize: 156.0,
                  cardWidth: 280.0,
                  showLogoHeader: true,
                  showFooter: true,
                ),
              ),

              const SizedBox(height: 14),

              // ── Live Countdown Timer & Status Badge ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusBorderColor(),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dynamic polling status indicator
                    Expanded(
                      child: Row(
                        children: [
                          _buildStatusIcon(),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getStatusLabel(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getStatusTextColor(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Countdown pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isLowTime
                            ? const Color(0xFFFEE2E2)
                            : Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isLowTime
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFFCBD5E1),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 13,
                            color: isLowTime
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF475569),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$minutes:$seconds',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: isLowTime
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Action Buttons ──
              if (_dialogState == AbaPaymentDialogState.expired) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF475569),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _handleCancel,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005A70),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          setState(() {
                            _secondsRemaining = widget.timeoutSeconds;
                            _dialogState = AbaPaymentDialogState.waiting;
                            _consecutiveFailures = 0;
                          });
                          _startCountdown();
                          _startPolling();
                        },
                        child: const Text(
                          'Retry Timer',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _handleCancel,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text(
                      'Cancel Payment',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (_dialogState) {
      case AbaPaymentDialogState.success:
        return const Icon(
          Icons.check_circle_rounded,
          size: 16,
          color: Color(0xFF16A34A),
        );
      case AbaPaymentDialogState.expired:
        return const Icon(
          Icons.error_outline_rounded,
          size: 16,
          color: Color(0xFFDC2626),
        );
      case AbaPaymentDialogState.checking:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF005A70)),
          ),
        );
      case AbaPaymentDialogState.waiting:
      case AbaPaymentDialogState.failed:
        return FadeTransition(
          opacity: _pulseAnimation,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF0D9488),
              shape: BoxShape.circle,
            ),
          ),
        );
    }
  }

  String _getStatusLabel() {
    if (_statusMessage != null) return _statusMessage!;
    switch (_dialogState) {
      case AbaPaymentDialogState.success:
        return 'Payment Approved! Finalizing...';
      case AbaPaymentDialogState.expired:
        return 'QR Code Expired';
      case AbaPaymentDialogState.checking:
        return 'Checking transaction...';
      case AbaPaymentDialogState.waiting:
        return 'Waiting for customer to scan...';
      case AbaPaymentDialogState.failed:
        return 'Awaiting payment confirmation...';
    }
  }

  Color _getStatusBgColor() {
    switch (_dialogState) {
      case AbaPaymentDialogState.success:
        return const Color(0xFFF0FDF4);
      case AbaPaymentDialogState.expired:
        return const Color(0xFFFEF2F2);
      case AbaPaymentDialogState.waiting:
      case AbaPaymentDialogState.checking:
      case AbaPaymentDialogState.failed:
        return const Color(0xFFF8FAFC);
    }
  }

  Color _getStatusBorderColor() {
    switch (_dialogState) {
      case AbaPaymentDialogState.success:
        return const Color(0xFFBBF7D0);
      case AbaPaymentDialogState.expired:
        return const Color(0xFFFECACA);
      case AbaPaymentDialogState.waiting:
      case AbaPaymentDialogState.checking:
      case AbaPaymentDialogState.failed:
        return const Color(0xFFE2E8F0);
    }
  }

  Color _getStatusTextColor() {
    switch (_dialogState) {
      case AbaPaymentDialogState.success:
        return const Color(0xFF15803D);
      case AbaPaymentDialogState.expired:
        return const Color(0xFFB91C1C);
      case AbaPaymentDialogState.waiting:
      case AbaPaymentDialogState.checking:
      case AbaPaymentDialogState.failed:
        return const Color(0xFF334155);
    }
  }
}
