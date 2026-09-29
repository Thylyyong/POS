import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../core/debouncer.dart';
import '../../../core/product_image_helper.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../core/theme/sprite_icons.dart';
import '../../../database/settings_dao.dart';
import '../../../models/product_model.dart';
import '../../../models/store_settings_model.dart';
import '../../../services/presentation_service.dart';
import '../../../widgets/aba_khqr_card.dart';
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

class _CustomerPresentationViewState extends State<CustomerPresentationView>
    with SingleTickerProviderStateMixin {
  final PresentationService _presentationService = PresentationService();
  final SettingsDao _settingsDao = SettingsDao();
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _debouncer = Debouncer(duration: const Duration(milliseconds: 300));

  PresentationPayload _payload = PresentationPayload(state: CfdScreenState.idle);
  StoreSettingsModel _settings = const StoreSettingsModel();
  String _currentTime = '';
  String _currentDate = '';
  Timer? _clockTimer;
  Timer? _menuSyncTimer;
  Timer? _adAutoPlayTimer;
  Timer? _idleReturnTimer;
  StreamSubscription<PresentationPayload>? _payloadSub;

  late PageController _adPageController;
  int _adCurrentPage = 0;
  bool _customerBrowsingMenu = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  int _ipcMenuSyncCount = 0;

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
    _adPageController = PageController();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.88, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _loadSettings();
    _loadIpcMenu();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());
    _menuSyncTimer = Timer.periodic(const Duration(seconds: 1), (_) => _loadIpcMenu());

    _payloadSub = _presentationService.listenOnCustomerDisplay((payload) {
      if (mounted) {
        setState(() {
          _payload = payload;
        });
        _syncFromPayload(payload);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAdAutoPlay();
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

  int _lastSyncedMenuVersion = 0;

  Future<void> _loadIpcMenu() async {
    try {
      try {
        final posCtrl = context.read<PosController>();
        await posCtrl.loadProducts();
        await posCtrl.loadCategories();
      } catch (_) {}

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
      _ipcMenuSyncCount++;
      if (_ipcMenuSyncCount % 3 == 0) {
        _loadSettings();
      }
    } catch (_) {}
  }

  void _startAdAutoPlay() {
    _adAutoPlayTimer?.cancel();
    final interval = _settings.promoAutoPlaySeconds.clamp(2, 30);
    _adAutoPlayTimer = Timer.periodic(Duration(seconds: interval), (_) {
      if (!mounted || !_adPageController.hasClients) return;
      final banners = _getEffectiveBanners();
      if (banners.isEmpty) return;
      final nextPage = (_adCurrentPage + 1) % banners.length;
      _adPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _startIdleReturnTimer() {
    _idleReturnTimer?.cancel();
    _idleReturnTimer = Timer(const Duration(seconds: 45), () {
      if (mounted) {
        setState(() => _customerBrowsingMenu = false);
      }
    });
  }

  List<String> _getEffectiveBanners() {
    if (_settings.promoBanners.isNotEmpty) {
      return _settings.promoBanners;
    }
    return StoreSettingsModel.defaultPromoBanners;
  }

  Future<void> _loadSettings() async {
    try {
      var s = await _settingsDao.getSettings();
      if (mounted) {
        final hadBanners = _settings.promoBanners.isNotEmpty;

        // ── Ensure cfdShowAdsWhenIdle defaults to true on first launch ──
        // If the DB key is missing or was never explicitly saved, it may be
        // false from an older DB schema. Force-persist the default=true once.
        if (!s.cfdShowAdsWhenIdle) {
          // Only override if not explicitly saved. We detect by checking if
          // a key exists that was saved alongside it (promoAutoPlaySeconds).
          // This is a one-time migration: save true back to DB.
          await _settingsDao.updateSingleSetting('cfd_show_ads_when_idle', '1');
          s = s.copyWith(cfdShowAdsWhenIdle: true);
        }

        setState(() => _settings = s);
        if (!hadBanners && s.promoBanners.isNotEmpty) {
          _startAdAutoPlay();
        }
      }
    } catch (_) {}
  }

  void _updateClock() {
    if (mounted) {
      final now = DateTime.now();
      setState(() {
        _currentTime = DateFormat('hh:mm:ss a').format(now);
        _currentDate = DateFormat('EEEE, MMMM d, yyyy').format(now);
      });
    }
  }

  void _syncFromPayload(PresentationPayload payload) {
    if (payload.items.isNotEmpty ||
        payload.state != CfdScreenState.idle ||
        (payload.qrData != null && payload.qrData!.isNotEmpty)) {
      if (_customerBrowsingMenu) {
        _idleReturnTimer?.cancel();
        _customerBrowsingMenu = false;
      }
    }

    if (payload.cfdShowAdsWhenIdle != null &&
        payload.cfdShowAdsWhenIdle != _settings.cfdShowAdsWhenIdle) {
      _settings = _settings.copyWith(cfdShowAdsWhenIdle: payload.cfdShowAdsWhenIdle);
    }

    // 1. Sync category, subcategory & products to local PosController
    try {
      final posCtrl = context.read<PosController>();
      if (payload.menuVersion != _lastSyncedMenuVersion) {
        _lastSyncedMenuVersion = payload.menuVersion;
        posCtrl.loadCategories();
        posCtrl.loadProducts();
        _loadIpcMenu();
      }
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

    // 3. Sync scroll offset for IPC scroll controller smoothly
    if (_ipcScrollController.hasClients) {
      if ((_ipcScrollController.offset - payload.scrollOffset).abs() > 4.0) {
        final maxExtent = _ipcScrollController.position.maxScrollExtent;
        _ipcScrollController.animateTo(
          payload.scrollOffset.clamp(0.0, maxExtent),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
        );
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
    _adAutoPlayTimer?.cancel();
    _idleReturnTimer?.cancel();
    _adPageController.dispose();
    _pulseCtrl.dispose();
    _ipcScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;

    SettingsController? settingsCtrl;
    try {
      settingsCtrl = context.watch<SettingsController>();
    } catch (_) {}
    final activeSettings = settingsCtrl?.settings ?? _settings;
    final storeName = activeSettings.storeName.isNotEmpty ? activeSettings.storeName : 'CA POS';

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

    // Reset customer browsing menu flag if items are actively present
    if (itemsList.isNotEmpty || isQrActive || isPaymentSuccess) {
      if (_customerBrowsingMenu) {
        _customerBrowsingMenu = false;
        _idleReturnTimer?.cancel();
      }
    }

    // Show fullscreen advertising when:
    // - Cart is empty (no active order) AND no QR / payment in progress
    // - Customer hasn't tapped screen to browse menu
    // - cfdShowAdsWhenIdle is NOT explicitly turned off in settings
    // NOTE: We default to showing ads (true) so even if DB has a stale value,
    //       ads still appear. Only explicit admin toggle-off hides them.
    final bool adsEnabled = activeSettings.cfdShowAdsWhenIdle;
    final bool shouldShowFullAds = adsEnabled &&
        itemsList.isEmpty &&
        !isQrActive &&
        !isPaymentSuccess &&
        !_customerBrowsingMenu &&
        _getEffectiveBanners().isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: shouldShowFullAds
          ? _buildFullAdvertisingView(context, activeSettings, canPop)
          : Scaffold(
              key: const ValueKey('cfd_split_order_screen'),
              backgroundColor: const Color(0xFFF8FAFC),
              body: SafeArea(
                child: Column(
                  children: [
                    // ── Top Customer Header Bar (Clean, NO Cashier Admin controls) ──
                    _buildCustomerHeader(context, storeName, canPop, posCtrl, itemsList, activeSettings),

                    // ── Main Dual-Column Content: Menu (Left) + Cart/QR (Right) ──
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Left Column: POS Menu (Categories, Subcategories, Items Grid) ──
                          Expanded(
                            flex: isQrActive ? 64 : 68,
                            child: _ipcProducts.isNotEmpty
                                ? _buildIpcMenu(context, liveCart, currency)
                                : (posCtrl != null && posCtrl.products.isNotEmpty)
                                    ? ItemGrid(
                                        isCustomerDisplay: true,
                                        gridTemplateOverride: _payload.gridTemplate,
                                        scrollController: _ipcScrollController,
                                      )
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
    List<Map<String, dynamic>> itemsList,
    StoreSettingsModel settings,
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

          // Show Ads button (when customer is browsing menu and cart is empty)
          if (settings.cfdShowAdsWhenIdle && itemsList.isEmpty) ...[
            InkWell(
              onTap: () {
                _idleReturnTimer?.cancel();
                setState(() => _customerBrowsingMenu = false);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tv_rounded, size: 14, color: Color(0xFF0D9488)),
                    SizedBox(width: 4),
                    Text(
                      'Show Ads',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

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

          // Items List / Promotional Advertising State when empty
          Expanded(
            child: itemsList.isEmpty
                ? _buildCfdPromotionBanner()
                : ListView.separated(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: itemsList.length,
                    separatorBuilder: (context, index) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = itemsList[index];
                      final qty = item['quantity'] ?? 1;
                      final name = item['productName'] ?? '';
                      final price = (item['totalPrice'] as num?)?.toDouble() ?? 0.0;
                      final imagePath = (item['imagePath'] as String?)?.trim();

                      final imgProvider = ProductImageHelper.resolveImageProvider(
                        imagePath: imagePath,
                        productName: name,
                      );

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Product Image Thumbnail
                          Container(
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image(
                                image: imgProvider,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stack) => Image.asset(
                                  ProductImageHelper.getDefaultAssetFor(productName: name),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error2, stack2) => const Center(
                                    child: AppSvgIcon(
                                      AssetTheme.gallery,
                                      size: 18,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

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

  /// ── Dynamic QR Payment View (Displays Partner ABA PAY KHQR Template) ──
  Widget _buildQrPaymentView(double totalAmount, String currency) {
    final qrData = _payload.qrData ?? 'OMNIPOS_PAYMENT_DEFAULT';

    final hasPayloadQrImage = _payload.qrImagePath != null &&
        _payload.qrImagePath!.isNotEmpty &&
        File(_payload.qrImagePath!).existsSync();
    final hasSettingsQrImage = _settings.qrImagePath != null &&
        _settings.qrImagePath!.isNotEmpty &&
        File(_settings.qrImagePath!).existsSync();
    final customQrPath = hasPayloadQrImage
        ? _payload.qrImagePath!
        : (hasSettingsQrImage ? _settings.qrImagePath! : null);

    final storeTitle = _settings.storeName.isNotEmpty ? _settings.storeName : 'CA POS';
    final rate = _settings.usdToKhrRate > 0 ? _settings.usdToKhrRate : 4000.0;
    final khrAmount = (totalAmount * rate).round();

    return Container(
      key: const ValueKey('qr_payment_view'),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Partner ABA PAY KHQR Card ──
              AbaKhqrCard(
                storeName: storeTitle,
                amount: totalAmount,
                khrAmount: khrAmount,
                currencySymbol: currency,
                qrData: qrData,
                qrImagePath: customQrPath,
                qrSize: 200.0,
                cardWidth: 300.0,
                showLogoHeader: true,
                showFooter: true,
              ),
              const SizedBox(height: 14),

              // ── Live Status Pulse Indicator ──
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
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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

  /// ── Fullscreen Customer Advertising Presentation ────────────────────────
  /// Rendered when cashier has no active order items and customer advertising
  /// is enabled in settings. Displays full-width cinematic food posters,
  /// store branding, live clock, slide dots, and interactive pulse prompt.
  Widget _buildFullAdvertisingView(
    BuildContext context,
    StoreSettingsModel settings,
    bool canPop,
  ) {
    final banners = _getEffectiveBanners();

    return Scaffold(
      key: const ValueKey('cfd_fullscreen_ads'),
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _customerBrowsingMenu = true;
          });
          _startIdleReturnTimer();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. Fullscreen Promotional Media Slideshow ──
            PageView.builder(
              controller: _adPageController,
              itemCount: banners.length,
              onPageChanged: (idx) => setState(() => _adCurrentPage = idx),
              itemBuilder: (context, index) {
                final bannerPath = banners[index];
                return _buildPromoSlide(bannerPath, index);
              },
            ),

            // ── 2. Cinematic Gradient Overlays ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.68),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.28, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // ── 3. Top Header: Store Branding & Live Clock ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Store Brand Logo & Name
                      Row(
                        children: [
                          AppLogoWidget(
                            logoPath: settings.logoPath,
                            size: 46,
                            borderRadius: 12,
                            fallbackSvg: AssetTheme.store,
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                settings.storeName.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  shadows: [
                                    Shadow(color: Colors.black87, blurRadius: 10),
                                  ],
                                ),
                              ),
                              Text(
                                settings.storeAddress.isNotEmpty
                                    ? settings.storeAddress
                                    : 'Welcome to our store',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Clock & Explore Menu Action
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 8),
                                Text(
                                  _currentTime,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Explore Menu Button
                          InkWell(
                            onTap: () {
                              setState(() => _customerBrowsingMenu = true);
                              _startIdleReturnTimer();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0D9488).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Explore Menu',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (canPop && !widget.isEmbeddedDualScreen) ...[
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () => Navigator.of(context).pop(),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 4. Bottom Section: Slide Dots & Touch to Order ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Slide Indicators
                      if (banners.length > 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(banners.length, (i) {
                            final isActive = i == _adCurrentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 6,
                              width: isActive ? 28 : 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF0D9488)
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Animated Call to Action
                      ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0D9488).withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, color: Colors.white, size: 24),
                              SizedBox(width: 10),
                              Text(
                                'TOUCH ANYWHERE TO START ORDER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _currentDate,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoSlide(String path, int index) {
    final isAsset = path.startsWith('assets/');
    final isFile = !isAsset && File(path).existsSync();

    Widget imageWidget;
    if (isAsset) {
      imageWidget = Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholderSlide(index),
      );
    } else if (isFile) {
      imageWidget = Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholderSlide(index),
      );
    } else {
      imageWidget = _buildPlaceholderSlide(index);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        imageWidget,
        // Promotional overlay caption
        Positioned(
          left: 36,
          bottom: 120,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D9488),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SPECIAL PROMOTION',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getPromoTitle(index),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPromoSubtitle(index),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 10),
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

  Widget _buildPlaceholderSlide(int index) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant_rounded, size: 80, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'PROMOTION SPECIALS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPromoTitle(int index) {
    switch (index % 4) {
      case 0:
        return 'Fresh Gourmet Selection';
      case 1:
        return 'Signature Handcrafted Drinks';
      case 2:
        return 'Artisan Burgers & Grills';
      case 3:
      default:
        return 'Delicious Combos & Deals';
    }
  }

  String _getPromoSubtitle(int index) {
    switch (index % 4) {
      case 0:
        return 'Made fresh to order with premium culinary ingredients.';
      case 1:
        return 'Pair your meal with our refreshing barista beverages.';
      case 2:
        return 'Sizzling hot, packed with flavor, and served immediately.';
      case 3:
      default:
        return 'Save more with our daily combos and value set meals.';
    }
  }

  Widget _buildCfdPromotionBanner() {
    final banners = _settings.promoBanners.isNotEmpty
        ? _settings.promoBanners
        : StoreSettingsModel.defaultPromoBanners;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CfdPromoCarousel(
                    banners: banners,
                    intervalSeconds: _settings.promoAutoPlaySeconds,
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.campaign_rounded, color: Color(0xFF38BDF8), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Special Promotion • Order at Counter',
                            style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 6),
              Text(
                'Browse our menu to start your order',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CfdPromoCarousel extends StatefulWidget {
  final List<String> banners;
  final int intervalSeconds;

  const _CfdPromoCarousel({
    required this.banners,
    this.intervalSeconds = 5,
  });

  @override
  State<_CfdPromoCarousel> createState() => _CfdPromoCarouselState();
}

class _CfdPromoCarouselState extends State<_CfdPromoCarousel> {
  late PageController _pageController;
  Timer? _timer;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(Duration(seconds: widget.intervalSeconds.clamp(2, 20)), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_current + 1) % widget.banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Icon(Icons.restaurant_rounded, size: 48, color: Color(0xFF94A3B8)),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: widget.banners.length,
      onPageChanged: (i) => setState(() => _current = i),
      itemBuilder: (context, index) {
        final path = widget.banners[index];
        final isAsset = path.startsWith('assets/');
        final isFile = !isAsset && File(path).existsSync();

        if (isAsset) {
          return Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder());
        } else if (isFile) {
          return Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder());
        }
        return _placeholder();
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF0F172A),
      child: const Center(
        child: Icon(Icons.restaurant_menu_rounded, color: Colors.white24, size: 40),
      ),
    );
  }
}

