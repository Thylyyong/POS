import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals, kIsWeb;
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
import '../../../widgets/promo_media_player.dart';

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
  State<CustomerPresentationView> createState() =>
      _CustomerPresentationViewState();
}

class _CustomerPresentationViewState extends State<CustomerPresentationView>
    with SingleTickerProviderStateMixin {
  final PresentationService _presentationService = PresentationService();
  final SettingsDao _settingsDao = SettingsDao();
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _debouncer = Debouncer(
    duration: const Duration(milliseconds: 300),
  );

  PresentationPayload _payload = PresentationPayload(
    state: CfdScreenState.idle,
  );
  StoreSettingsModel _settings = const StoreSettingsModel();
  String _currentTime = '';
  Timer? _clockTimer;
  Timer? _menuSyncTimer;
  Timer? _adAutoPlayTimer;
  Timer? _idleReturnTimer;
  StreamSubscription<PresentationPayload>? _payloadSub;

  late PageController _adPageController;
  int _adCurrentPage = 0;
  bool _customerBrowsingMenu = false;

  // ignore: unused_field
  List<Category> _ipcCategories = [];
  // ignore: unused_field
  List<Subcategory> _ipcSubcategories = [];
  // ignore: unused_field
  List<Product> _ipcProducts = [];
  String _ipcSelectedCategoryId = 'ALL';
  String? _ipcSelectedSubcategoryId;
  final ScrollController _ipcScrollController = ScrollController();

  String _lastMenuFileContent = '';
  String _lastSettingsFileContent = '';
  // Force-reload key: incremented every time banners/settings change to bust widget cache
  int _mediaCacheVersion = 0;

  @override
  void initState() {
    super.initState();
    _payload = _presentationService.latestPayload;
    _adPageController = PageController();

    _loadSettings();
    _loadIpcMenu();
    _updateClock();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateClock(),
    );
    _menuSyncTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _loadIpcMenu();
      _loadSettings();
    });

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
      if (!kIsWeb) {
        final menuFile = File(
          '${Directory.systemTemp.path}/omni_pos_cfd_menu.json',
        );
        if (await menuFile.exists()) {
          final text = await menuFile.readAsString();
          if (text.isNotEmpty && text != _lastMenuFileContent) {
            _lastMenuFileContent = text;
            final data = jsonDecode(text) as Map<String, dynamic>;
            final catList =
                (data['categories'] as List<dynamic>?)
                    ?.map(
                      (c) =>
                          Category.fromMap(Map<String, dynamic>.from(c as Map)),
                    )
                    .toList() ??
                [];
            final subList =
                (data['subcategories'] as List<dynamic>?)
                    ?.map(
                      (s) => Subcategory.fromMap(
                        Map<String, dynamic>.from(s as Map),
                      ),
                    )
                    .toList() ??
                [];
            final prodList =
                (data['products'] as List<dynamic>?)
                    ?.map(
                      (p) =>
                          Product.fromMap(Map<String, dynamic>.from(p as Map)),
                    )
                    .toList() ??
                [];
            if (prodList.isNotEmpty && mounted) {
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();
              setState(() {
                _ipcCategories = catList;
                _ipcSubcategories = subList;
                _ipcProducts = prodList;
              });
            }
          }
        }
      }
    } catch (_) {}
  }

  void _startAdAutoPlay() {
    _adAutoPlayTimer?.cancel();
    final interval = _settings.promoAutoPlaySeconds.clamp(2, 30);
    _adAutoPlayTimer = Timer.periodic(Duration(seconds: interval), (_) {
      if (!mounted || !_adPageController.hasClients) return;
      final banners = _getEffectiveBanners();
      if (banners.length <= 1) return;
      final current = _adPageController.page?.round() ?? _adCurrentPage;
      final nextPage = (current + 1) % banners.length;
      _adPageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  List<String> _getEffectiveBanners([StoreSettingsModel? override]) {
    StoreSettingsModel s = override ?? _settings;
    if (s.promoBanners.isNotEmpty) {
      return s.promoBanners;
    }
    if (override == null && mounted) {
      try {
        final ctrl = context.read<SettingsController?>();
        if (ctrl != null && ctrl.settings.promoBanners.isNotEmpty) {
          return ctrl.settings.promoBanners;
        }
      } catch (_) {}
    }
    return StoreSettingsModel.defaultPromoBanners;
  }

  Future<void> _loadSettings() async {
    try {
      StoreSettingsModel? s;
      if (!kIsWeb) {
        final settingsFile = File(
          '${Directory.systemTemp.path}/omni_pos_cfd_settings.json',
        );
        if (await settingsFile.exists()) {
          final content = await settingsFile.readAsString();
          if (content.isNotEmpty && content != _lastSettingsFileContent) {
            _lastSettingsFileContent = content;
            final map = jsonDecode(content) as Map<String, dynamic>;
            final stringMap = map.map(
              (k, v) => MapEntry(k, v?.toString() ?? ''),
            );
            s = StoreSettingsModel.fromMap(stringMap);
          }
        }
      }

      if (s == null) {
        final dbSettings = await _settingsDao.getSettings();
        if (!listEquals(_settings.promoBanners, dbSettings.promoBanners) ||
            _settings.storeName != dbSettings.storeName ||
            _settings.logoPath != dbSettings.logoPath ||
            _settings.promoAutoPlaySeconds != dbSettings.promoAutoPlaySeconds ||
            _settings.promoMediaFit != dbSettings.promoMediaFit) {
          s = dbSettings;
        }
      }

      if (s != null && mounted) {
        if (!s.cfdShowAdsWhenIdle) {
          await _settingsDao.updateSingleSetting('cfd_show_ads_when_idle', '1');
          s = s.copyWith(cfdShowAdsWhenIdle: true);
        }

        final bool bannersListChanged = !listEquals(
          _settings.promoBanners,
          s.promoBanners,
        );
        final bool intervalChanged =
            _settings.promoAutoPlaySeconds != s.promoAutoPlaySeconds;
        final bool fitChanged = _settings.promoMediaFit != s.promoMediaFit;
        final bool adsVisibilityChanged =
            _settings.cfdShowAdsWhenIdle != s.cfdShowAdsWhenIdle;
        final bool brandingChanged =
            _settings.storeName != s.storeName ||
            _settings.storeAddress != s.storeAddress ||
            _settings.logoPath != s.logoPath;

        final bool settingsChanged =
            bannersListChanged ||
            intervalChanged ||
            fitChanged ||
            adsVisibilityChanged ||
            brandingChanged;

        if (settingsChanged) {
          if (bannersListChanged || brandingChanged) {
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
          }
          setState(() {
            _settings = s!;
            if (bannersListChanged) {
              _mediaCacheVersion++; // Force all PromoMediaPlayer widgets to rebuild with fresh media
              _adCurrentPage = 0;
              if (_adPageController.hasClients) {
                _adPageController.jumpToPage(0);
              }
            }
          });
          if (bannersListChanged || intervalChanged) {
            _startAdAutoPlay();
          }
        }
      }
    } catch (_) {}
  }

  void _updateClock() {
    if (mounted) {
      final now = DateTime.now();
      setState(() {
        _currentTime = DateFormat('hh:mm:ss a').format(now);
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

    // Live synchronization of store settings & advertising from payload
    bool settingsChanged = false;
    bool bannersListChanged = false;
    bool intervalChanged = false;
    StoreSettingsModel newSettings = _settings;

    if (payload.promoBanners != null &&
        !listEquals(payload.promoBanners, _settings.promoBanners)) {
      newSettings = newSettings.copyWith(promoBanners: payload.promoBanners);
      settingsChanged = true;
      bannersListChanged = true;
      // Aggressively bust image/video cache so CDS shows new media immediately
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
    if (payload.promoAutoPlaySeconds != null &&
        payload.promoAutoPlaySeconds != _settings.promoAutoPlaySeconds) {
      newSettings = newSettings.copyWith(
        promoAutoPlaySeconds: payload.promoAutoPlaySeconds,
      );
      settingsChanged = true;
      intervalChanged = true;
    }
    if (payload.promoMediaFit != null &&
        payload.promoMediaFit != _settings.promoMediaFit) {
      newSettings = newSettings.copyWith(promoMediaFit: payload.promoMediaFit);
      settingsChanged = true;
    }
    if (payload.cfdShowAdsWhenIdle != null &&
        payload.cfdShowAdsWhenIdle != _settings.cfdShowAdsWhenIdle) {
      newSettings = newSettings.copyWith(
        cfdShowAdsWhenIdle: payload.cfdShowAdsWhenIdle,
      );
      settingsChanged = true;
    }
    if (payload.storeName != null && payload.storeName != _settings.storeName) {
      newSettings = newSettings.copyWith(storeName: payload.storeName);
      settingsChanged = true;
    }
    if (payload.storeAddress != null &&
        payload.storeAddress != _settings.storeAddress) {
      newSettings = newSettings.copyWith(storeAddress: payload.storeAddress);
      settingsChanged = true;
    }
    if (payload.logoPath != null && payload.logoPath != _settings.logoPath) {
      newSettings = newSettings.copyWith(logoPath: payload.logoPath);
      settingsChanged = true;
    }

    if (settingsChanged) {
      try {
        final ctrl = context.read<SettingsController?>();
        if (ctrl != null) {
          ctrl.updateSettings(newSettings);
        }
      } catch (_) {}
      setState(() {
        _settings = newSettings;
        if (bannersListChanged) {
          _mediaCacheVersion++; // Force all PromoMediaPlayer widgets to rebuild
          _adCurrentPage = 0;
          if (_adPageController.hasClients) {
            _adPageController.jumpToPage(0);
          }
        }
      });
      if (bannersListChanged || intervalChanged) {
        _startAdAutoPlay();
      }
    }

    if (payload.activePromoIndex != null &&
        payload.activePromoIndex != _adCurrentPage) {
      final banners = _getEffectiveBanners(newSettings);
      if (payload.activePromoIndex! >= 0 &&
          payload.activePromoIndex! < banners.length) {
        _adCurrentPage = payload.activePromoIndex!;
        if (_adPageController.hasClients) {
          _adPageController.animateToPage(
            _adCurrentPage,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
          );
        }
      }
    }

    // 1. Sync category, subcategory & products to local PosController
    try {
      final posCtrl = context.read<PosController>();
      if (payload.menuVersion != _lastSyncedMenuVersion) {
        _lastSyncedMenuVersion = payload.menuVersion;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        posCtrl.loadCategories();
        posCtrl.loadProducts();
        _loadIpcMenu();
      }
      if (payload.selectedCategoryId != posCtrl.selectedCategoryId) {
        posCtrl.selectCategory(payload.selectedCategoryId, broadcast: false);
      }
      if (payload.selectedSubcategoryId != posCtrl.selectedSubcategoryId) {
        posCtrl.selectSubcategory(
          payload.selectedSubcategoryId,
          broadcast: false,
        );
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final ctrl = context.watch<SettingsController>();
      final s = ctrl.settings;
      final bool bannersChanged = !listEquals(
        _settings.promoBanners,
        s.promoBanners,
      );
      final bool intervalChanged =
          _settings.promoAutoPlaySeconds != s.promoAutoPlaySeconds;
      final bool fitChanged = _settings.promoMediaFit != s.promoMediaFit;
      final bool adsVisibilityChanged =
          _settings.cfdShowAdsWhenIdle != s.cfdShowAdsWhenIdle;
      final bool brandingChanged =
          _settings.storeName != s.storeName ||
          _settings.storeAddress != s.storeAddress ||
          _settings.logoPath != s.logoPath;

      if (bannersChanged ||
          intervalChanged ||
          fitChanged ||
          adsVisibilityChanged ||
          brandingChanged) {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        _settings = s;
        if (bannersChanged) {
          _mediaCacheVersion++;
          _adCurrentPage = 0;
          if (_adPageController.hasClients) {
            _adPageController.jumpToPage(0);
          }
        }
        if (bannersChanged || intervalChanged) {
          _startAdAutoPlay();
        }
      }
    } catch (_) {}
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
    // If _settings has custom promo banners or received updates, prioritize it over stale controller
    final activeSettings =
        (_settings.promoBanners.isNotEmpty &&
            !listEquals(
              _settings.promoBanners,
              StoreSettingsModel.defaultPromoBanners,
            ))
        ? _settings
        : (settingsCtrl?.settings ?? _settings);
    final storeName = activeSettings.storeName.isNotEmpty
        ? activeSettings.storeName
        : 'CA POS';

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
    final double discountAmount = useLiveCart
        ? liveCart.discountAmount
        : _payload.discountAmount;
    final double taxAmount = useLiveCart
        ? liveCart.taxAmount
        : _payload.taxAmount;
    final double totalAmount = useLiveCart
        ? liveCart.totalAmount
        : _payload.totalAmount;
    final String currency = useLiveCart
        ? liveCart.currencySymbol
        : _payload.currencySymbol;

    PosController? posCtrl;
    try {
      posCtrl = context.watch<PosController>();
    } catch (_) {}

    final isQrActive =
        _payload.state == CfdScreenState.paymentQr ||
        (_payload.qrData != null && _payload.qrData!.isNotEmpty);
    final isPaymentSuccess = _payload.state == CfdScreenState.paymentSuccess;

    // Reset customer browsing menu flag if items are actively present
    if (itemsList.isNotEmpty || isQrActive || isPaymentSuccess) {
      if (_customerBrowsingMenu) {
        _customerBrowsingMenu = false;
        _idleReturnTimer?.cancel();
      }
    }

    // Show clean fullscreen promotional slideshow with time and Powered by CA when idle (no items & no QR/payment)
    final bool isIdle = itemsList.isEmpty && !isQrActive && !isPaymentSuccess;
    final bool useWelcomeMode =
        isIdle && activeSettings.cfdIdleMode == 'welcome';
    final bool useSlideShowMode =
        isIdle && activeSettings.cfdIdleMode == 'slideshow';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: isIdle
          ? (useWelcomeMode
                ? _buildWelcomeIdleView(context, activeSettings, canPop)
                : (useSlideShowMode || activeSettings.cfdIdleMode == 'mirror'
                      ? _buildCleanFullscreenAdView(
                          context,
                          activeSettings,
                          canPop,
                        )
                      : _buildCleanFullscreenAdView(
                          context,
                          activeSettings,
                          canPop,
                        )))
          : Scaffold(
              key: const ValueKey('cfd_split_order_screen'),
              backgroundColor: const Color(0xFFF8FAFC),
              body: SafeArea(
                child: Column(
                  children: [
                    // ── Top Customer Header Bar (Store Name, Time, Powered by CA) ──
                    _buildCustomerHeader(
                      context,
                      storeName,
                      canPop,
                      posCtrl,
                      itemsList,
                      activeSettings,
                    ),

                    // ── Main Content: Promotional Slideshow (Left) + Cart/QR (Right) ──
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: isQrActive ? 55 : 60,
                            child: _buildPromoSlideshowPanel(activeSettings),
                          ),
                          Container(width: 1, color: const Color(0xFFE2E8F0)),
                          Expanded(
                            flex: isQrActive ? 36 : 32,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: isQrActive
                                  ? _buildQrPaymentView(totalAmount, currency)
                                  : isPaymentSuccess
                                  ? _buildPaymentSuccessView(
                                      totalAmount,
                                      currency,
                                    )
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
          // Powered by CA badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogoWidget(
                  logoPath: 'assets/images/ca.png',
                  size: 15,
                  borderRadius: 3,
                  fallbackSvg: AssetTheme.store,
                ),
                SizedBox(width: 6),
                Text(
                  'Powered by CA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Live Clock Timing
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppSvgIcon(
                  AssetTheme.clock,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  _currentTime,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                const AppSvgIcon(
                  AssetTheme.cart,
                  size: 16,
                  color: Color(0xFF0F172A),
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
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
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: itemsList.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 12, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final item = itemsList[index];
                      final qty = item['quantity'] ?? 1;
                      final name = item['productName'] ?? '';
                      final price =
                          (item['totalPrice'] as num?)?.toDouble() ?? 0.0;
                      final imagePath = (item['imagePath'] as String?)?.trim();

                      final imgProvider =
                          ProductImageHelper.resolveImageProvider(
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
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image(
                                image: imgProvider,
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stack) => Image.asset(
                                  ProductImageHelper.getDefaultAssetFor(
                                    productName: name,
                                  ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error2, stack2) =>
                                      const Center(
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '$currency${subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tax / VAT',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '$currency${taxAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                if (discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Discount',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppConfig.accentRose,
                        ),
                      ),
                      Text(
                        '-$currency${discountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: AppConfig.accentRose,
                        ),
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
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

    final hasPayloadQrImage =
        _payload.qrImagePath != null &&
        _payload.qrImagePath!.isNotEmpty &&
        File(_payload.qrImagePath!).existsSync();
    final hasSettingsQrImage =
        _settings.qrImagePath != null &&
        _settings.qrImagePath!.isNotEmpty &&
        File(_settings.qrImagePath!).existsSync();
    final customQrPath = hasPayloadQrImage
        ? _payload.qrImagePath!
        : (hasSettingsQrImage ? _settings.qrImagePath! : null);

    final storeTitle = _settings.storeName.isNotEmpty
        ? _settings.storeName
        : 'CA POS';
    final rate = _settings.usdToKhrRate > 0 ? _settings.usdToKhrRate : 4000.0;
    final khrAmount = (totalAmount * rate).round();

    return Container(
      key: const ValueKey('qr_payment_view'),
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0D9488).withValues(alpha: 0.28),
          width: 1.5,
        ),
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

              if (_payload.receiptNo != null &&
                  _payload.receiptNo!.isNotEmpty) ...[
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
                  child: AppSvgIcon.sprite(
                    SpriteIcons.check,
                    size: 34,
                    color: Colors.white,
                  ),
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
                (_payload.thankYouNote != null &&
                        _payload.thankYouNote!.trim().isNotEmpty)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
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
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D9488)
                                  .withValues(alpha: 0.1),
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
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
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
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
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
                              AppSvgIcon.sprite(
                                SpriteIcons.cash,
                                size: 16,
                                color: Color(0xFF059669),
                              ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSvgIcon.sprite(
                      SpriteIcons.star,
                      size: 16,
                      color: Color(0xFF059669),
                    ),
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

  Widget _buildWelcomeIdleView(
    BuildContext context,
    StoreSettingsModel settings,
    bool canPop,
  ) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLogoWidget(
                          logoPath: settings.logoPath ?? 'assets/images/ca.png',
                          size: 18,
                          borderRadius: 5,
                          monochrome: true,
                          fallbackSvg: AssetTheme.store,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Powered by CA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppLogoWidget(
                    logoPath: settings.logoPath ?? 'assets/images/ca.png',
                    size: 120,
                    borderRadius: 28,
                    monochrome: true,
                    fallbackSvg: AssetTheme.store,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    settings.storeName.isNotEmpty
                        ? settings.storeName
                        : 'Welcome',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Welcome',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (canPop && !widget.isEmbeddedDualScreen)
              Positioned(
                top: 18,
                right: 18,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ── Clean Fullscreen Promotional Ads with Time & Powered by CA ──────────
  /// When idle (no items in cart): shows the promotional image slideshow edge-to-edge
  /// overlaid only with the live clock (time) and "Powered by CA" logo badge.
  Widget _buildCleanFullscreenAdView(
    BuildContext context,
    StoreSettingsModel settings,
    bool canPop,
  ) {
    final banners = _getEffectiveBanners(settings);

    return Scaffold(
      key: const ValueKey('cfd_fullscreen_ads_clean'),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Image Slideshow (Full Screen edge-to-edge) ──
          if (banners.isNotEmpty)
            PageView.builder(
              key: ValueKey(
                'cfd_clean_pageview_${banners.join(",")}_${settings.promoMediaFit}_$_mediaCacheVersion',
              ),
              controller: _adPageController,
              itemCount: banners.length,
              onPageChanged: (idx) => setState(() => _adCurrentPage = idx),
              itemBuilder: (context, index) {
                return _buildPromoSlide(banners[index], index, settings);
              },
            )
          else
            Container(
              color: const Color(0xFF0F172A),
              child: const Center(
                child: Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white24,
                  size: 64,
                ),
              ),
            ),

          // ── Top subtle gradient vignette for text legibility ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 90,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Top Overlay Bar: Only Time & Powered by CA (+ Close if preview) ──
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: SafeArea(
              child: Row(
                children: [
                  // Powered by CA
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppLogoWidget(
                          logoPath: settings.logoPath ?? 'assets/images/ca.png',
                          size: 16,
                          borderRadius: 4,
                          monochrome: true,
                          fallbackSvg: AssetTheme.store,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Powered by CA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Live Clock (Time)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          _currentTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Close button if modal preview
                  if (canPop && !widget.isEmbeddedDualScreen) ...[
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Bottom Slide Dots Indicator ──
          if (banners.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(banners.length, (i) {
                  final isActive = i == _adCurrentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    width: isActive ? 24 : 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  /// ── Promotional Slideshow Panel for Split Checkout Screen ────────────────
  Widget _buildPromoSlideshowPanel(StoreSettingsModel settings) {
    final banners = _getEffectiveBanners(settings);
    if (banners.isEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Icon(
            Icons.storefront_rounded,
            size: 64,
            color: Colors.white24,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          key: ValueKey(
            'cfd_split_promo_${banners.join(",")}_${settings.promoMediaFit}_$_mediaCacheVersion',
          ),
          controller: _adPageController,
          itemCount: banners.length,
          onPageChanged: (idx) => setState(() => _adCurrentPage = idx),
          itemBuilder: (context, index) {
            return _buildPromoSlide(banners[index], index, settings);
          },
        ),
        if (banners.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(banners.length, (i) {
                final isActive = i == _adCurrentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 4,
                  width: isActive ? 20 : 5,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  BoxFit _resolveBoxFit(String fitMode) {
    switch (fitMode) {
      case 'fill':
        return BoxFit.fill;
      case 'cover':
      case 'contain':
      default:
        return BoxFit.cover;
    }
  }

  Widget _buildPromoSlide(
    String path,
    int index, [
    StoreSettingsModel? settingsOverride,
  ]) {
    final s = settingsOverride ?? _settings;
    final fit = _resolveBoxFit(s.promoMediaFit);
    return PromoMediaPlayer(
      // Include _mediaCacheVersion in key so widget fully rebuilds when banners change
      key: ValueKey(
        'cfd_promo_${path}_${s.promoMediaFit}_${index}_$_mediaCacheVersion',
      ),
      mediaPath: path,
      index: index,
      showFull: false,
      fit: fit,
      autoPlay: true,
      loop: true,
      muted: true,
    );
  }

  Widget _buildCfdPromotionBanner([StoreSettingsModel? settingsOverride]) {
    final s = settingsOverride ?? _settings;
    final banners = _getEffectiveBanners(s);

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
                    key: ValueKey(
                      'cfd_promo_banner_${banners.join(",")}_${s.promoAutoPlaySeconds}_${s.promoMediaFit}_$_mediaCacheVersion',
                    ),
                    banners: banners,
                    intervalSeconds: s.promoAutoPlaySeconds,
                    fitMode: s.promoMediaFit,
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.campaign_rounded,
                            color: Color(0xFF38BDF8),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Special Promotion • Order at Counter',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
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
  final String fitMode;

  const _CfdPromoCarousel({
    super.key,
    required this.banners,
    this.intervalSeconds = 5,
    this.fitMode = 'cover',
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
  void didUpdateWidget(_CfdPromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.banners, widget.banners) ||
        oldWidget.intervalSeconds != widget.intervalSeconds ||
        oldWidget.fitMode != widget.fitMode) {
      _startTimer();
    }
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
    _timer = Timer.periodic(
      Duration(seconds: widget.intervalSeconds.clamp(2, 30)),
      (_) {
        if (!mounted || !_pageController.hasClients) return;
        final next = (_current + 1) % widget.banners.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  BoxFit _resolveBoxFit(String fitMode) {
    switch (fitMode) {
      case 'fill':
        return BoxFit.fill;
      case 'cover':
      case 'contain':
      default:
        return BoxFit.cover;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
          child: Icon(
            Icons.restaurant_rounded,
            size: 48,
            color: Color(0xFF94A3B8),
          ),
        ),
      );
    }

    final fit = _resolveBoxFit(widget.fitMode);

    return PageView.builder(
      controller: _pageController,
      itemCount: widget.banners.length,
      onPageChanged: (i) => setState(() => _current = i),
      itemBuilder: (context, index) {
        final path = widget.banners[index];
        return PromoMediaPlayer(
          key: ValueKey('cfd_carousel_${path}_${widget.fitMode}_$index'),
          mediaPath: path,
          index: index,
          showFull: false,
          fit: fit,
        );
      },
    );
  }
}
