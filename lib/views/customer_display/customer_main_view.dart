import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app_config.dart';
import '../../../database/settings_dao.dart';
import '../../../models/store_settings_model.dart';
import '../../../services/presentation_service.dart';
import '../../../widgets/app_logo_widget.dart';
import '../cashier/cashier_main_layout.dart';
import '../cashier/widgets/nav_sidebar.dart';

class CustomerMainView extends StatefulWidget {
  const CustomerMainView({super.key});

  @override
  State<CustomerMainView> createState() => _CustomerMainViewState();
}

class _CustomerMainViewState extends State<CustomerMainView> {
  final PresentationService _presentationService = PresentationService();
  final SettingsDao _settingsDao = SettingsDao();

  PresentationPayload _payload = PresentationPayload(state: CfdScreenState.idle);
  StoreSettingsModel _settings = const StoreSettingsModel();
  String _currentTime = '';
  Timer? _clockTimer;
  StreamSubscription<PresentationPayload>? _payloadSub;

  @override
  void initState() {
    super.initState();
    _payload = _presentationService.latestPayload;
    _loadSettings();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    _payloadSub = _presentationService.listenOnCustomerDisplay((payload) {
      if (mounted) {
        setState(() {
          _payload = payload;
        });
      }
    });
  }

  Future<void> _loadSettings() async {
    try {
      final s = await _settingsDao.getSettings();
      if (mounted) {
        setState(() => _settings = s);
      }
    } catch (_) {}
  }

  void _updateClock() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('hh:mm a').format(DateTime.now());
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
    final storeName = _settings.storeName.isNotEmpty ? _settings.storeName : 'The Culinary Canvas';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Slim Header Bar ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  // Dashboard Navigation Button
                  IconButton(
                    icon: const Icon(Icons.dashboard_outlined, color: Color(0xFF0F172A), size: 22),
                    tooltip: 'Go to Dashboard',
                    onPressed: () {
                      if (canPop) {
                        Navigator.of(parentContext).pop();
                      }
                      Navigator.of(parentContext).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const CashierMainLayout(initialTab: CashierNavTab.dashboard),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  Text(
                    storeName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),

                  // Live Clock
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          _currentTime,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Main Dual-Column Content ────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left Column (32% Width): Order Items Table (Item Name first, xQTY, Price) ────
                  Expanded(
                    flex: 32,
                    child: Container(
                      margin: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Table Header (ITEM & PRICE)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ITEM',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF64748B),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  'PRICE',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Items List (Product Name first, then 'xAmount', Price on right)
                          Expanded(
                            child: _payload.items.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.receipt_long_outlined, size: 42, color: const Color(0xFFCBD5E1)),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'No items currently added',
                                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    itemCount: _payload.items.length,
                                    separatorBuilder: (context, index) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, index) {
                                      final item = _payload.items[index];
                                      final qty = item['quantity'] ?? 1;
                                      final name = item['productName'] ?? '';
                                      final price = (item['totalPrice'] as num?)?.toDouble() ?? 0.0;

                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    name,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'x$qty',
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${_payload.currencySymbol}${price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),

                          // Summary Footer Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Subtotal', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                    Text(
                                      '${_payload.currencySymbol}${_payload.subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('VAT (10%)', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                    Text(
                                      '${_payload.currencySymbol}${_payload.taxAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                if (_payload.discountAmount > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Discount', style: TextStyle(fontSize: 12.5, color: AppConfig.accentRose)),
                                      Text(
                                        '-${_payload.currencySymbol}${_payload.discountAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppConfig.accentRose),
                                      ),
                                    ],
                                  ),
                                ],
                                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Total Due',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      '${_payload.currencySymbol}${_payload.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Right Column (68% Width): Prominent Store Logo & Branding Showcase (80% scale focus) ──
                  Expanded(
                    flex: 68,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Scale the logo dynamically to be prominent and fill the view
                          final logoSize = (constraints.maxHeight * 0.85).clamp(480.0, 580.0);

                          return Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Large Store Logo (Showcased prominently)
                                  AppLogoWidget(
                                    logoPath: _settings.logoPath,
                                    size: logoSize,
                                    borderRadius: logoSize * 0.22,
                                    fallbackIcon: Icons.restaurant,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.10),
                                        blurRadius: 28,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  // Store Title (Prominent and bold)
                                  Text(
                                    storeName,
                                    style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.8,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),

                                  // Store Address / Tagline
                                  Text(
                                    _settings.storeAddress.isNotEmpty
                                        ? _settings.storeAddress
                                        : 'Welcome! Enjoy your dining experience with us.',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),

                                  // QR Code payment box if active
                                  if (_payload.state == CfdScreenState.paymentQr ||
                                      (_payload.qrData != null && _payload.qrData!.isNotEmpty)) ...[
                                    const SizedBox(height: 26),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          QrImageView(
                                            data: _payload.qrData!,
                                            version: QrVersions.auto,
                                            size: 100,
                                            backgroundColor: Colors.transparent,
                                          ),
                                          const SizedBox(width: 16),
                                          const Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'SCAN TO PAY',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Scan with your camera or banking app',
                                                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
