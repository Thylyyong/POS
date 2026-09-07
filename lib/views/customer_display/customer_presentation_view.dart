import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../database/settings_dao.dart';
import '../../../models/store_settings_model.dart';
import '../../../services/presentation_service.dart';
import '../../../widgets/app_logo_widget.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_svg_icon.dart';

/// Customer-Facing Display (CFD / CDS).
/// Shows live items, quantities, and prices on the left.
/// Shows the prominent Store Logo on the right, which dynamically swaps
/// into the QR Payment Code when the cashier initiates QR payment.
class CustomerPresentationView extends StatefulWidget {
  final bool showDashboardButton;
  final bool isEmbeddedDualScreen;

  const CustomerPresentationView({
    super.key,
    this.showDashboardButton = false,
    this.isEmbeddedDualScreen = false,
  });

  @override
  State<CustomerPresentationView> createState() => _CustomerPresentationViewState();
}

class _CustomerPresentationViewState extends State<CustomerPresentationView> {
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
    final storeName = _settings.storeName.isNotEmpty ? _settings.storeName : 'CA POS';

    // Reactive check for live CartController in widget tree
    CartController? liveCart;
    try {
      liveCart = parentContext.watch<CartController>();
    } catch (_) {}

    final List<Map<String, dynamic>> itemsList = liveCart != null
        ? liveCart.items.map((i) => i.toPresentationMap()).toList()
        : _payload.items;
    final double subtotal = liveCart != null ? liveCart.subtotal : _payload.subtotal;
    final double discountAmount = liveCart != null ? liveCart.discountAmount : _payload.discountAmount;
    final double taxAmount = liveCart != null ? liveCart.taxAmount : _payload.taxAmount;
    final double totalAmount = liveCart != null ? liveCart.totalAmount : _payload.totalAmount;
    final String currency = liveCart != null ? liveCart.currencySymbol : _payload.currencySymbol;

    final isQrActive = _payload.state == CfdScreenState.paymentQr ||
        (_payload.qrData != null && _payload.qrData!.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  AppLogoWidget(
                    logoPath: _settings.logoPath,
                    size: 28,
                    borderRadius: 6,
                    fallbackSvg: AssetTheme.store,
                  ),
                  const SizedBox(width: 10),

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

                  // Live Status Indicator Tag
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6.5,
                          height: 6.5,
                          decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'LIVE DISPLAY',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

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
                        const AppSvgIcon(AssetTheme.clock, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 6),
                        Text(
                          _currentTime,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                  ),

                  // Return to POS button (only when pushed in-app)
                  if (canPop && !widget.isEmbeddedDualScreen) ...[
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => Navigator.of(parentContext).pop(),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppSvgIcon(AssetTheme.close, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Return to POS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Main Dual-Column Content ────────────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left Column (34% Width): Live Order Items Table & Totals ──
                  Expanded(
                    flex: 34,
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

                          // Items List
                          Expanded(
                            child: itemsList.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        AppSvgIcon(AssetTheme.files, size: 40, color: Color(0xFFCBD5E1)),
                                        SizedBox(height: 10),
                                        Text(
                                          'No items currently added',
                                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    itemCount: itemsList.length,
                                    separatorBuilder: (context, index) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                                    itemBuilder: (context, index) {
                                      final item = itemsList[index];
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
                                            '$currency${price.toStringAsFixed(2)}',
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
                                      '$currency${subtotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Tax / VAT', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                                    Text(
                                      '$currency${taxAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                if (discountAmount > 0) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Discount', style: TextStyle(fontSize: 12.5, color: AppConfig.accentRose)),
                                      Text(
                                        '-$currency${discountAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppConfig.accentRose),
                                      ),
                                    ],
                                  ),
                                ],
                                const Divider(height: 14, color: Color(0xFFCBD5E1)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'TOTAL DUE',
                                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      '$currency${totalAmount.toStringAsFixed(2)}',
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

                  // ── Right Column (66% Width): Dynamic Branding Logo OR QR Payment Display ──
                  Expanded(
                    flex: 66,
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
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: isQrActive
                            ? _buildQrPaymentView(totalAmount, currency)
                            : _buildStoreLogoView(storeName),
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

  /// 1. Dynamic QR Payment View (Replaces logo when QR Pay is clicked)
  Widget _buildQrPaymentView(double totalAmount, String currency) {
    final qrData = _payload.qrData ?? 'OMNIPOS_PAYMENT_DEFAULT';
    final amountFormatted = '$currency${totalAmount.toStringAsFixed(2)}';

    return Center(
      key: const ValueKey('qr_payment_view'),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Status Header Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSvgIcon(AssetTheme.searchQR, color: Color(0xFF0D9488), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'QR CODE PAYMENT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D9488),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Large Total Amount
            Text(
              amountFormatted,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please scan the QR code to complete your payment',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            // Prominent QR Code Box
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 240,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF0F172A),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Instructions Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppSvgIcon(AssetTheme.gallery, size: 16, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Text(
                    'Compatible with Mobile Banking & Camera scanners',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 2. Default Store Branding & Logo View (Shown when cart is idle / active)
  Widget _buildStoreLogoView(String storeName) {
    return LayoutBuilder(
      key: const ValueKey('branding_logo_view'),
      builder: (context, constraints) {
        final logoSize = (constraints.maxHeight * 0.55).clamp(180.0, 320.0);

        return Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Prominent Logo
                AppLogoWidget(
                  logoPath: _settings.logoPath,
                  size: logoSize,
                  borderRadius: logoSize * 0.22,
                  fallbackSvg: AssetTheme.store,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Store Title
                Text(
                  storeName,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Tagline / Welcome
                Text(
                  _settings.storeAddress.isNotEmpty
                      ? _settings.storeAddress
                      : 'Welcome! Thank you for dining with us.',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
