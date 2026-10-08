import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/settings_controller.dart';
import '../../models/store_settings_model.dart';
import '../../services/presentation_service.dart';
import '../../widgets/app_logo_widget.dart';
import '../../widgets/promo_media_player.dart';
import '../splash/splash_screen.dart';

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
  final PresentationService _presentationService = PresentationService();
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

  int? _lastAutoPlaySeconds;
  List<String>? _lastBanners;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.watch<SettingsController>().settings;
    if (_lastAutoPlaySeconds != settings.promoAutoPlaySeconds ||
        !listEquals(_lastBanners, settings.promoBanners)) {
      _lastAutoPlaySeconds = settings.promoAutoPlaySeconds;
      _lastBanners = List<String>.from(settings.promoBanners);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      _startAutoPlay();
    }
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
      if (promoBanners.length <= 1) return;

      final current = _pageController.page?.round() ?? _currentPage;
      final nextPage = (current + 1) % promoBanners.length;
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
              key: ValueKey('main_ads_carousel_${banners.join(",")}_${settings.promoMediaFit}'),
              controller: _pageController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                _presentationService.syncActivePromoSlide(index);
              },
              itemBuilder: (context, index) {
                final bannerPath = banners[index];
                return _buildPromoSlide(bannerPath, index);
              },
            ),

            // ── 2. Subtle Dark Vignette & Gradient Overlays ──
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.38),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                      ],
                      stops: const [0.0, 0.22, 0.70, 1.0],
                    ),
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


  Widget _buildPromoSlide(String path, int index) {
    final settings = context.watch<SettingsController>().settings;
    final fit = _resolveBoxFit(settings.promoMediaFit);

    return PromoMediaPlayer(
      key: ValueKey('main_promo_${path}_${settings.promoMediaFit}_$index'),
      mediaPath: path,
      index: index,
      showFull: false,
      fit: fit,
      autoPlay: true,
      loop: true,
      muted: true,
    );
  }
}
