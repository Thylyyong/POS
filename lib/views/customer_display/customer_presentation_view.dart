import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../core/debouncer.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../core/theme/sprite_icons.dart';
import '../../../database/settings_dao.dart';
import '../../../models/product_model.dart';
import '../../../models/store_settings_model.dart';
import '../../../services/presentation_service.dart';
import '../../../widgets/app_logo_widget.dart';
import '../../../widgets/app_svg_icon.dart';
import '../cashier/widgets/item_grid.dart';

/// Customer-Facing Display (CFD / Dual-Screen Customer View).
/// Displays:
/// 1. A clean customer header (Store Logo, Name, Live Search, Status & Clock)
///    without any cashier controls (No Owner, No Register Open/Close, No Cash In/Out,
///    No Kick Drawer, No Print, No Duplicate Screen).
/// 2. Left Column (68%): Full POS Menu (`ItemGrid`) with scrollable categories,
///    subcategories, and product cards grid.
/// 3. Right Column (32%): Live Order Cart Summary, QR Payment view when active,
///    or Payment Completed state.
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
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _debouncer = Debouncer(duration: const Duration(milliseconds: 300));

  PresentationPayload _payload = PresentationPayload(state: CfdScreenState.idle);
  StoreSettingsModel _settings = const StoreSettingsModel();
  String _currentTime = '';
  Timer? _clockTimer;
  Timer? _menuSyncTimer;
  StreamSubscription<PresentationPayload>? _payloadSub;

  List<Category> _ipcCategories = [];
  List<Subcategory> _ipcSubcategories = [];
  List<Product> _ipcProducts = [];
  String _ipcSelectedCategoryId = 'ALL';
  String? _ipcSelectedSubcategoryId;
  final ScrollController _ipcScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _payload = _presentationService.latestPayload;
    _loadSettings();
    _loadIpcMenu();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _menuSyncTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadIpcMenu());

    _payloadSub = _presentationService.listenOnCustomerDisplay((payload) {
      if (mounted) {
        setState(() {
          _payload = payload;
        });
        _syncFromPayload(payload);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final posCtrl = context.read<PosController>();
        if (posCtrl.categories.isEmpty) {
          posCtrl.loadCategories();
        }
        if (posCtrl.products.isEmpty) {
          posCtrl.loadProducts();
        }
      } catch (_) {}
    });
  }

  Future<void> _loadIpcMenu() async {
    try {
      final data = await _presentationService.readMenuForCustomerDisplay();
      if (data != null && mounted) {
        final catList = (data['categories'] as List<dynamic>?)
                ?.map((c) => Category.fromMap(Map<String, dynamic>.from(c as Map)))
                .toList() ??
            [];
        final subList = (data['subcategories'] as List<dynamic>?)
                ?.map((s) => Subcategory.fromMap(Map<String, dynamic>.from(s as Map)))
                .toList() ??
            [];
        final prodList = (data['products'] as List<dynamic>?)
                ?.map((p) => Product.fromMap(Map<String, dynamic>.from(p as Map)))
                .toList() ??
            [];
        if (prodList.isNotEmpty && mounted) {
          setState(() {
            _ipcCategories = catList;
            _ipcSubcategories = subList;
            _ipcProducts = prodList;
          });
        }
      }
    } catch (_) {}
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

  void _syncFromPayload(PresentationPayload payload) {
    // 1. Sync category & subcategory to local PosController (if present in widget tree)
    try {
      final posCtrl = context.read<PosController>();
      if (payload.selectedCategoryId != posCtrl.selectedCategoryId) {
        posCtrl.selectCategory(payload.selectedCategoryId, broadcast: false);
      }
      if (payload.selectedSubcategoryId != posCtrl.selectedSubcategoryId) {
        posCtrl.selectSubcategory(payload.selectedSubcategoryId, broadcast: false);
      }
      if (payload.searchQuery != posCtrl.searchQuery) {
        posCtrl.setSearchQuery(payload.searchQuery, broadcast: false);
        if (_searchCtrl.text != payload.searchQuery) {
          _searchCtrl.text = payload.searchQuery;
        }
      }
      if ((posCtrl.scrollOffset - payload.scrollOffset).abs() > 4.0) {
        posCtrl.setScrollOffset(payload.scrollOffset, broadcast: false);
      }
    } catch (_) {}

    // 2. Also sync to IPC state variables (for standalone mode when SQLite is isolated)
    if (_ipcSelectedCategoryId != payload.selectedCategoryId ||
        _ipcSelectedSubcategoryId != payload.selectedSubcategoryId) {
      setState(() {
        _ipcSelectedCategoryId = payload.selectedCategoryId;
        _ipcSelectedSubcategoryId = payload.selectedSubcategoryId;
      });
    }

    // 3. Sync scroll offset for IPC scroll controller
    if (_ipcScrollController.hasClients) {
      if ((_ipcScrollController.offset - payload.scrollOffset).abs() > 4.0) {
        final maxExtent = _ipcScrollController.position.maxScrollExtent;
        _ipcScrollController.jumpTo(payload.scrollOffset.clamp(0.0, maxExtent));
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.cancel();
    _payloadSub?.cancel();
    _clockTimer?.cancel();
    _menuSyncTimer?.cancel();
    _ipcScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    final storeName = _settings.storeName.isNotEmpty ? _settings.storeName : 'CA POS';

    // Reactive check for live CartController in widget tree
    CartController? liveCart;
    try {
      liveCart = context.watch<CartController>();
    } catch (_) {}

    final bool useLiveCart = liveCart != null && liveCart.items.isNotEmpty;
    final List<Map<String, dynamic>> itemsList = useLiveCart
        ? liveCart.items.map((i) => i.toPresentationMap()).toList()
        : _payload.items;
    final double subtotal = useLiveCart ? liveCart.subtotal : _payload.subtotal;
    final double discountAmount = useLiveCart ? liveCart.discountAmount : _payload.discountAmount;
    final double taxAmount = useLiveCart ? liveCart.taxAmount : _payload.taxAmount;
    final double totalAmount = useLiveCart ? liveCart.totalAmount : _payload.totalAmount;
    final String currency = useLiveCart ? liveCart.currencySymbol : _payload.currencySymbol;

    PosController? posCtrl;
    try {
      posCtrl = context.watch<PosController>();
    } catch (_) {}

    final isQrActive = _payload.state == CfdScreenState.paymentQr ||
        (_payload.qrData != null && _payload.qrData!.isNotEmpty);
    final isPaymentSuccess = _payload.state == CfdScreenState.paymentSuccess;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Customer Header Bar (Clean, NO Cashier Admin controls) ──
            _buildCustomerHeader(context, storeName, canPop, posCtrl),

            // ── Main Dual-Column Content: Menu (Left) + Cart/QR (Right) ──
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left Column: POS Menu (Categories, Subcategories, Items Grid) ──
                  Expanded(
                    flex: isQrActive ? 64 : 68,
                    child: (posCtrl != null && posCtrl.products.isNotEmpty)
                        ? ItemGrid(
                            isCustomerDisplay: true,
                            gridTemplateOverride: _payload.gridTemplate,
                          )
                        : _ipcProducts.isNotEmpty
                            ? _buildIpcMenu(context, liveCart, currency)
                            : Container(
                                color: ColorTheme.screenBg,
                                child: const Center(
                                  child: Text(
                                    'Loading menu...',
                                    style: TextStyle(color: ColorTheme.neutral500, fontSize: 14),
                                  ),
                                ),
                              ),
                  ),

                  // Vertical Separator
                  Container(width: 1, color: const Color(0xFFE2E8F0)),

                  // ── Right Column: Live Cart / QR Payment / Payment Success ──
                  Expanded(
                    flex: isQrActive ? 36 : 32,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: isQrActive
                          ? _buildQrPaymentView(totalAmount, currency)
                          : isPaymentSuccess
                              ? _buildPaymentSuccessView(totalAmount, currency)
                              : _buildCartPanel(
                                  itemsList,
                                  subtotal,
                                  discountAmount,
                                  taxAmount,
                                  totalAmount,
                                  currency,
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

  /// ── Customer Top Header Bar ─────────────────────────────────────────────
  /// Designed specifically for customer-facing display: Clean store branding,
  /// customer search bar, live status tag, and clock.
  /// Cashier-only buttons (Owner, Register Open/Close, Cash In/Out, Drawer Kick,
  /// Print, Duplicate Screen, Navigation Menu) are deliberately excluded.
  Widget _buildCustomerHeader(
    BuildContext context,
    String storeName,
    bool canPop,
    PosController? posCtrl,
  ) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Store Logo
          AppLogoWidget(
            logoPath: _settings.logoPath,
            size: 32,
            borderRadius: 8,
            fallbackSvg: AssetTheme.store,
          ),
          const SizedBox(width: 10),

          // Store Name & Subtitle
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                storeName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                _settings.storeAddress.isNotEmpty
                    ? _settings.storeAddress
                    : 'Customer Display',
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),

          // Live Search Bar (filters ItemGrid)
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    _debouncer.call(() {
                      posCtrl?.setSearchQuery(val);
                    });
                    setState(() {});
                  },
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search menu items...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.5,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 10, right: 6),
                      child: AppSvgIcon(
                        AssetTheme.search,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const AppSvgIcon(
                              AssetTheme.close,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              _debouncer.cancel();
                              posCtrl?.clearSearch();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    fillColor: const Color(0xFFF1F5F9),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF0F172A),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const Spacer(),

          // Customer Display Indicator Badge
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
                  'CUSTOMER DISPLAY',
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

          // Return to POS button (only when modal preview / canPop)
          if (canPop && !widget.isEmbeddedDualScreen) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: () => Navigator.of(context).pop(),
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
    );
  }

  /// ── Customer Cart / Order Panel ─────────────────────────────────────────
  Widget _buildCartPanel(
    List<Map<String, dynamic>> itemsList,
    double subtotal,
    double discountAmount,
    double taxAmount,
    double totalAmount,
    String currency,
  ) {
    return Container(
      key: const ValueKey('cart_panel_view'),
      margin: const EdgeInsets.all(12),
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
          // Order Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const AppSvgIcon(AssetTheme.cart, size: 16, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                const Text(
                  'Current Order',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${itemsList.length} items',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items Table Header (ITEM & PRICE)
          if (itemsList.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'ITEM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    'PRICE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

          // Items List / Empty State
          Expanded(
            child: itemsList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: AppSvgIcon(AssetTheme.cart, size: 28, color: Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Your order is empty',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Select items from the menu to build your order.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'x$qty',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$currency${price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13.5,
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
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
    );
  }

  /// ── Dynamic QR Payment View (Replaces cart panel when QR Pay is initiated) ──
  Widget _buildQrPaymentView(double totalAmount, String currency) {
    final qrData = _payload.qrData ?? 'OMNIPOS_PAYMENT_DEFAULT';
    final amountFormatted = '$currency${totalAmount.toStringAsFixed(2)}';

    final hasPayloadQrImage = _payload.qrImagePath != null &&
        _payload.qrImagePath!.isNotEmpty &&
        File(_payload.qrImagePath!).existsSync();
    final hasSettingsQrImage = _settings.qrImagePath != null &&
        _settings.qrImagePath!.isNotEmpty &&
        File(_settings.qrImagePath!).existsSync();
    final hasCustomQrImage = hasPayloadQrImage || hasSettingsQrImage;
    final customQrPath = hasPayloadQrImage
        ? _payload.qrImagePath!
        : (hasSettingsQrImage ? _settings.qrImagePath! : '');

    final storeTitle = _settings.storeName.isNotEmpty ? _settings.storeName : 'CA POS';
    final storeSubtitle = _settings.storeAddress.isNotEmpty
        ? _settings.storeAddress
        : 'Official Merchant Terminal';

    return Container(
      key: const ValueKey('qr_payment_view'),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.28), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── 1. Store Identity Header (Store Logo + Name + Verified Badge) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Store Logo
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: AppLogoWidget(
                        logoPath: _settings.logoPath,
                        size: 48,
                        borderRadius: 10,
                        fallbackSvg: AssetTheme.store,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Store Name and Verified Subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            storeTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.4,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const AppSvgIcon.sprite(SpriteIcons.checkCircle, size: 13, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  storeSubtitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 14),

              // ── 2. "SCAN TO PAY" Pill Badge ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSvgIcon(AssetTheme.searchQR, color: Color(0xFF0D9488), size: 15),
                    SizedBox(width: 6),
                    Text(
                      'SCAN TO PAY',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D9488),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── 3. Total Amount ──
              Text(
                amountFormatted,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Scan with any banking or wallet app',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),

              // ── 4. Prominent, Significantly Enlarged QR Code Box ──
              LayoutBuilder(
                builder: (context, constraints) {
                  // Dynamically size QR code to fill available space generously
                  final availableW = constraints.maxWidth - 32;
                  final qrSize = availableW.clamp(260.0, 330.0);

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // The QR Code Image or generated QrImageView
                        hasCustomQrImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(customQrPath),
                                  width: qrSize,
                                  height: qrSize,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: qrSize,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: Color(0xFF0F172A),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Color(0xFF0F172A),
                                ),
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                              ),

                        // High-tech corner bracket indicators
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _ScannerCornerPainter(
                                color: const Color(0xFF0D9488),
                                strokeWidth: 2.5,
                                cornerLength: 20.0,
                                radius: 10.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // ── 5. Compatible Networks Badge ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSvgIcon(AssetTheme.gallery, size: 14, color: Color(0xFF0D9488)),
                    SizedBox(width: 8),
                    Text(
                      'Supports PromptPay, Bakong, VietQR & UPI',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── 6. Live Status Pulse Indicator ──
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Ready for customer scan',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              if (_payload.receiptNo != null && _payload.receiptNo!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Bill #${_payload.receiptNo}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// ── Payment Completed View ───────────────────────────────────────────────
  Widget _buildPaymentSuccessView(double totalAmount, String currency) {
    final receiptNo = _payload.receiptNo ?? '';
    final changeAmount = _payload.changeAmount ?? 0.0;
    final storeTitle = _settings.storeName.isNotEmpty
        ? _settings.storeName
        : 'Restaurant & Cafe';
    final storeSubtitle = _settings.storeAddress.isNotEmpty
        ? _settings.storeAddress
        : 'Thank You for Visiting!';

    return Container(
      key: const ValueKey('payment_success_view'),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Store Logo & Identity at the Top
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: AppLogoWidget(
                  logoPath: _settings.logoPath,
                  size: 76,
                  borderRadius: 38,
                  fallbackSvg: AssetTheme.store,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                storeTitle.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (storeSubtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  storeSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 18),

              // 2. Celebratory Success Checkmark Badge
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: AppSvgIcon.sprite(SpriteIcons.check, size: 34, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Welcoming Warm Greeting
              const Text(
                'Thank You!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                (_payload.thankYouNote != null && _payload.thankYouNote!.trim().isNotEmpty)
                    ? _payload.thankYouNote!
                    : 'We truly appreciate your visit! Please come again soon.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 18),

              // 4. Payment Receipt & Amounts Summary Card
              Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    if (receiptNo.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Order Receipt:',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$receiptNo',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Amount Paid:',
                          style: TextStyle(fontSize: 13.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$currency${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    if (_settings.showKhrDualCurrency) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total (KHR):',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${NumberFormat('#,###').format((totalAmount * _settings.usdToKhrRate).round())} KHR',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (changeAmount > 0) ...[
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              AppSvgIcon.sprite(SpriteIcons.cash, size: 16, color: Color(0xFF059669)),
                              SizedBox(width: 6),
                              Text(
                                'Change Returned:',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$currency${changeAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Friendly Hospitality Bottom Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSvgIcon.sprite(SpriteIcons.star, size: 16, color: Color(0xFF059669)),
                    SizedBox(width: 6),
                    Text(
                      'Have a wonderful day! Please visit us again.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF047857),
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

  /// ── Standalone IPC Menu View (Used when secondary process reads synced menu) ──
  Widget _buildIpcMenu(BuildContext context, CartController? liveCart, String currency) {
    var displayProducts = _ipcProducts;
    if (_searchCtrl.text.trim().isNotEmpty) {
      final q = _searchCtrl.text.trim().toLowerCase();
      displayProducts = displayProducts.where((p) => p.name.toLowerCase().contains(q)).toList();
    } else if (_ipcSelectedCategoryId != 'ALL') {
      displayProducts = displayProducts.where((p) => p.categoryId == _ipcSelectedCategoryId).toList();
      if (_ipcSelectedSubcategoryId != null) {
        displayProducts = displayProducts.where((p) => p.subcategoryId == _ipcSelectedSubcategoryId).toList();
      }
    }

    final subcatsForSelectedCat = _ipcCategories.isNotEmpty && _ipcSelectedCategoryId != 'ALL'
        ? _ipcSubcategories.where((s) => s.categoryId == _ipcSelectedCategoryId).toList()
        : <Subcategory>[];

    return Container(
      color: ColorTheme.screenBg,
      child: Column(
        children: [
          // Category bar
          CategoryBar(
            categories: _ipcCategories,
            selectedId: _ipcSelectedCategoryId,
            onSelect: (catId) {
              setState(() {
                _ipcSelectedCategoryId = catId;
                _ipcSelectedSubcategoryId = null;
              });
            },
          ),

          // Subcategory bar
          if (_ipcSelectedCategoryId != 'ALL' && subcatsForSelectedCat.isNotEmpty)
            SubcategoryBar(
              subcategories: subcatsForSelectedCat,
              selectedId: _ipcSelectedSubcategoryId,
              onSelect: (subId) {
                setState(() => _ipcSelectedSubcategoryId = subId);
              },
            ),

          // Product cards grid
          Expanded(
            child: displayProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppSvgIcon(
                          AssetTheme.allCate,
                          size: 52,
                          color: ColorTheme.neutral400.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No menu items found',
                          style: TextStyle(color: ColorTheme.neutral600, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final template = _payload.gridTemplate.isNotEmpty
                          ? _payload.gridTemplate
                          : _settings.gridTemplate;
                      final layout = ProductGrid.resolveGridLayout(
                        maxWidth: constraints.maxWidth,
                        gridTemplate: template,
                      );

                      return GridView.builder(
                        controller: _ipcScrollController,
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: layout.crossAxisCount,
                          childAspectRatio: layout.childAspectRatio,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: displayProducts.length,
                        itemBuilder: (ctx, index) {
                          final p = displayProducts[index];
                          return ProductCard(
                            product: p,
                            currency: currency,
                            onTap: () {
                              if (liveCart != null) {
                                liveCart.addProduct(p);
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Modern L-shaped scanner corner bracket painter for QR display containers
class _ScannerCornerPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double radius;

  _ScannerCornerPainter({
    required this.color,
    this.strokeWidth = 2.5,
    this.cornerLength = 20.0,
    this.radius = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final l = cornerLength;
    final r = radius;

    // Top-left corner
    final pathTL = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(l, 0);
    canvas.drawPath(pathTL, paint);

    // Top-right corner
    final pathTR = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, l);
    canvas.drawPath(pathTR, paint);

    // Bottom-left corner
    final pathBL = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..quadraticBezierTo(0, h, r, h)
      ..lineTo(l, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-right corner
    final pathBR = Path()
      ..moveTo(w - l, h)
      ..lineTo(w - r, h)
      ..quadraticBezierTo(w, h, w, h - r)
      ..lineTo(w, h - l);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
