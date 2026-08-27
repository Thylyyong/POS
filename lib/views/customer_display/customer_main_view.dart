import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app_config.dart';
import '../../../services/presentation_service.dart';
import 'widgets/qr_display.dart';

class CustomerMainView extends StatefulWidget {
  const CustomerMainView({super.key});

  @override
  State<CustomerMainView> createState() => _CustomerMainViewState();
}

class _CustomerMainViewState extends State<CustomerMainView> {
  final PresentationService _presentationService = PresentationService();

  PresentationPayload _payload = PresentationPayload(state: CfdScreenState.idle);
  String _currentTime = '';
  Timer? _clockTimer;
  StreamSubscription<PresentationPayload>? _payloadSub;

  @override
  void initState() {
    super.initState();
    _payload = _presentationService.latestPayload;
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    // Listen to real-time events from Main Cashier Display
    _payloadSub = _presentationService.listenOnCustomerDisplay((payload) {
      if (mounted) {
        setState(() {
          _payload = payload;
        });
      }
    });
  }

  void _updateClock() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('hh:mm:ss a • EEE, MMM d').format(DateTime.now());
      });
    }
  }

  @override
  void dispose() {
    _payloadSub?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext parentContext) {
    final canPop = Navigator.maybeOf(parentContext)?.canPop() ?? false;
    return Theme(
      data: AppConfig.darkTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              // Top CFD Header
              _buildCfdHeader(parentContext, canPop),

                  // Dynamic Body based on State
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: _buildCurrentStateView(),
                    ),
                  ),

                  // Bottom CFD Footer Bar
                  _buildCfdFooter(),
                ],
              ),
            ),
          ),
        );
      }

  Widget _buildCfdHeader(BuildContext ctx, bool canPop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (canPop) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  tooltip: 'Back to Cashier',
                  onPressed: () {
                    Navigator.maybeOf(ctx)?.pop();
                  },
                ),
                const SizedBox(width: 8),
              ],
              const Icon(Icons.storefront, color: AppConfig.accentGreen, size: 28),
              const SizedBox(width: 12),
              const Text(
                'CUSTOMER FACING DISPLAY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.access_time, color: Color(0xFF94A3B8), size: 16),
              const SizedBox(width: 6),
              Text(
                _currentTime,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStateView() {
    switch (_payload.state) {
      case CfdScreenState.idle:
        return _buildIdleView();
      case CfdScreenState.cartActive:
      case CfdScreenState.paymentPending:
        return _buildCartActiveView();
      case CfdScreenState.paymentQr:
        return _buildPaymentQrView();
      case CfdScreenState.paymentSuccess:
        return _buildPaymentSuccessView();
    }
  }

  // 1. Idle View (Welcome screen with restaurant ambiance)
  Widget _buildIdleView() {
    return Center(
      key: const ValueKey('idle_view'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppConfig.accentGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppConfig.accentGreen.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(Icons.restaurant_menu, size: 80, color: AppConfig.accentGreen),
          ),
          const SizedBox(height: 24),
          const Text(
            'Welcome to Our Restaurant!',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your live order items and totals will appear here.',
            style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // 2. Cart Active View (Real Product Photo Thumbnails + Items Table + Amount Due)
  Widget _buildCartActiveView() {
    final currency = _payload.currencySymbol;

    return Row(
      key: const ValueKey('cart_active_view'),
      children: [
        // Left Column: Items Table with Product Images
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 5, child: Text('ITEM / PRODUCT', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), fontSize: 13))),
                      Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), fontSize: 13))),
                      Expanded(flex: 3, child: Text('PRICE', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), fontSize: 13))),
                    ],
                  ),
                ),
                // Items List with Real Product Image Thumbnails
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _payload.items.length,
                    separatorBuilder: (_, _) => const Divider(height: 16, color: Color(0xFF334155)),
                    itemBuilder: (context, index) {
                      final item = _payload.items[index];
                      final imagePath = item['imagePath'] as String?;
                      ImageProvider? imgProvider;
                      if (imagePath != null && imagePath.trim().isNotEmpty) {
                        if (imagePath.trim().startsWith('assets/')) {
                          imgProvider = AssetImage(imagePath.trim());
                        } else if (File(imagePath.trim()).existsSync()) {
                          imgProvider = FileImage(File(imagePath.trim()));
                        }
                      }

                      return Row(
                        children: [
                          // Product Image Thumbnail from Assets or Local Storage
                          Container(
                            width: 46,
                            height: 46,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(10),
                              image: imgProvider != null
                                  ? DecorationImage(
                                      image: imgProvider,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: imgProvider == null
                                ? const Icon(Icons.fastfood, size: 22, color: AppConfig.accentCyan)
                                : null,
                          ),

                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['productName'] ?? '',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                                if (item['notes'] != null && (item['notes'] as String).isNotEmpty)
                                  Text(
                                    '* ${item['notes']}',
                                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${item['quantity']}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConfig.accentCyan),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              '$currency${((item['totalPrice'] ?? 0.0) as num).toStringAsFixed(2)}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right Column: Summary Card & Big Total Due & Payment Method
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.only(top: 20, bottom: 20, right: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('ORDER AMOUNT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                const SizedBox(height: 20),
                _buildSummaryRow('Subtotal', '$currency${_payload.subtotal.toStringAsFixed(2)}'),
                if (_payload.discountAmount > 0)
                  _buildSummaryRow('Discount', '-$currency${_payload.discountAmount.toStringAsFixed(2)}', color: AppConfig.accentRose),
                if (_payload.taxAmount > 0)
                  _buildSummaryRow('Tax / VAT', '$currency${_payload.taxAmount.toStringAsFixed(2)}'),
                
                const Spacer(),
                const Divider(height: 32, color: Color(0xFF334155)),

                // Big Total Amount Due Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppConfig.accentGreen.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TOTAL AMOUNT DUE',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$currency${_payload.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: AppConfig.accentGreen),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Status Indicator
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppConfig.accentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConfig.accentCyan.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payment, color: AppConfig.accentCyan, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Cash or Mobile QR Accepted',
                        style: TextStyle(color: AppConfig.accentCyan, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 3. Payment QR View
  Widget _buildPaymentQrView() {
    return Center(
      key: const ValueKey('payment_qr_view'),
      child: CfdQrDisplay(
        qrData: _payload.qrData ?? '',
        totalAmount: _payload.totalAmount,
        currencySymbol: _payload.currencySymbol,
      ),
    );
  }

  // 4. Payment Success View
  Widget _buildPaymentSuccessView() {
    final currency = _payload.currencySymbol;
    return Center(
      key: const ValueKey('payment_success_view'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppConfig.accentGreen.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppConfig.accentGreen, width: 3),
            ),
            child: const Icon(Icons.check_circle, size: 84, color: AppConfig.accentGreen),
          ),
          const SizedBox(height: 24),
          const Text(
            'Payment Received!',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            'Receipt #${_payload.receiptNo ?? ""} • Total Paid: $currency${_payload.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18, color: AppConfig.accentCyan, fontWeight: FontWeight.w600),
          ),
          if ((_payload.changeAmount ?? 0) > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Change Due: $currency${_payload.changeAmount!.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppConfig.accentAmber),
            ),
          ],
          const SizedBox(height: 24),
          if (_payload.thankYouNote != null && _payload.thankYouNote!.isNotEmpty)
            Text(
              _payload.thankYouNote!,
              style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
            )
          else
            const Text(
              'Thank you for your visit! Have a great day.',
              style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8)),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8))),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color ?? Colors.white)),
        ],
      ),
    );
  }

  Widget _buildCfdFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155), width: 1.5)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: AppConfig.accentGreen, size: 16),
              SizedBox(width: 6),
              Text(
                '100% Offline Dual-Screen Mirroring Active',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
          Text(
            'Powered by OmniPOS',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
