import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../models/store_settings_model.dart';
import '../../widgets/admin_pin_dialog.dart';
import '../../widgets/app_logo_widget.dart';
import '../splash/splash_screen.dart';
import 'manage_promotions_dialog.dart';

/// Fullscreen Advertising / Promotion Screen.
/// 
/// Displayed when:
/// 1. The terminal starts up or is in screensaver / idle mode.
/// 2. No customer order is actively being prepared.
/// 3. Cashier taps "Idle / Lock" button from the POS.
/// 
/// Behavior:
/// - Auto-rotates promotional images/posters.
/// - When tapped anywhere on the screen: smoothly navigates to the Login/Role screen.
/// - Includes an Admin quick button (PIN protected) to add/manage promotion images and rotation speed.
class AdvertisingScreen extends StatefulWidget {
  const AdvertisingScreen({super.key});

  @override
  State<AdvertisingScreen> createState() => _AdvertisingScreenState();
}

class _AdvertisingScreenState extends State<AdvertisingScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  Timer? _autoPlayTimer;
  Timer? _clockTimer;
  String _currentTime = '';
  String _currentDate = '';
  int _currentPage = 0;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _updateClock();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) => _updateClock());

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoPlay();
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _clockTimer?.cancel();
    _pageController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _updateClock() {
    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm:ss a').format(now);
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(now);
    if (mounted) {
      setState(() {
        _currentTime = timeStr;
        _currentDate = dateStr;
      });
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    final settings = context.read<SettingsController>().settings;
    final interval = settings.promoAutoPlaySeconds.clamp(2, 30);

    _autoPlayTimer = Timer.periodic(Duration(seconds: interval), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final promoBanners = _getEffectiveBanners(settings);
      if (promoBanners.isEmpty) return;

      final nextPage = (_currentPage + 1) % promoBanners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  List<String> _getEffectiveBanners(StoreSettingsModel settings) {
    if (settings.promoBanners.isNotEmpty) {
      return settings.promoBanners;
    }
    return StoreSettingsModel.defaultPromoBanners;
  }

  void _navigateToLogin() {
    _autoPlayTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => const SplashScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  Future<void> _openManagePromotions() async {
    _autoPlayTimer?.cancel();
    final verified = await AdminPinDialog.show(
      context,
      title: 'Admin Verification',
      subtitle: 'Enter Admin PIN to manage promotional advertisements',
    );

    if (verified && mounted) {
      await ManagePromotionsDialog.show(context);
    }

    if (mounted) {
      _startAutoPlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final banners = _getEffectiveBanners(settings);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToLogin,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. Fullscreen Promotional Media Carousel ──
            PageView.builder(
              controller: _pageController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final bannerPath = banners[index];
                return _buildPromoSlide(bannerPath, index);
              },
            ),

            // ── 2. Subtle Dark Vignette & Gradient Overlays ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0.0, 0.25, 0.65, 1.0],
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

                      // Clock & Admin Promotion Settings Button
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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

                          // Admin Gear / Ads Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _openManagePromotions,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: const Tooltip(
                                  message: 'Admin: Manage Promotion Ads',
                                  child: Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── 4. Bottom Section: Interactive Call-To-Action & Slide Dots ──
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
                            final isActive = i == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              height: 6,
                              width: isActive ? 28 : 8,
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF0D9488) : Colors.white.withValues(alpha: 0.4),
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
                          color: Colors.white.withValues(alpha: 0.7),
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
      imageWidget = Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, _, _) => _buildPlaceholderSlide(index));
    } else if (isFile) {
      imageWidget = Image.file(File(path), fit: BoxFit.cover, errorBuilder: (_, _, _) => _buildPlaceholderSlide(index));
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
}
