import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/device_profile.dart';
import '../../widgets/app_logo_widget.dart';
import '../advertising/advertising_screen.dart';
import '../cashier/cashier_main_layout.dart';
import '../cashier/widgets/nav_sidebar.dart';

/// Owner Splash Launcher Portal.
/// 
/// Displayed immediately when the Owner/Boss signs in with PIN.
/// Provides 2 BIG, high-impact options to choose between:
/// 1. POS Terminal (Frontline register, tables, orders, checkout)
/// 2. Admin Dashboard (Reports, P&L accounting, settings, catalog)
class OwnerPortalScreen extends StatefulWidget {
  const OwnerPortalScreen({super.key});

  @override
  State<OwnerPortalScreen> createState() => _OwnerPortalScreenState();
}

class _OwnerPortalScreenState extends State<OwnerPortalScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _navigateToTab(CashierNavTab tab) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => CashierMainLayout(initialTab: tab),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  void _lockOrSwitchUser() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => const AdvertisingScreen(),
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
    final auth = context.watch<AuthController>();
    final isKiosk = DeviceProfile.isKiosk(context, deviceProfile: settings.deviceProfile);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  AppLogoWidget(
                    logoPath: settings.logoPath,
                    size: 38,
                    borderRadius: 10,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        settings.storeName.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'OmniPOS Enterprise • Multi-Branch Suite',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Owner Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_user_rounded, color: Color(0xFF7C3AED), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          auth.currentUser.displayName,
                          style: const TextStyle(
                            color: Color(0xFF7C3AED),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // Lock / Switch User Button
                  OutlinedButton.icon(
                    onPressed: _lockOrSwitchUser,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    icon: const Icon(Icons.lock_outline_rounded, size: 16),
                    label: const Text('Lock / Switch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // ── Main Body: 2 Big Splash Options ──
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Welcome Title
                          const Text(
                            'WELCOME BACK, OWNER',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Where would you like to go?',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // 2 Big Option Cards Container
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isKiosk ? 500 : 960,
                            ),
                            child: isKiosk
                                ? Column(
                                    children: [
                                      _buildPosCard(isKiosk: true),
                                      const SizedBox(height: 20),
                                      _buildDashboardCard(isKiosk: true),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildPosCard(isKiosk: false)),
                                      const SizedBox(width: 24),
                                      Expanded(child: _buildDashboardCard(isKiosk: false)),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card 1: Point of Sale (POS) ──
  Widget _buildPosCard({required bool isKiosk}) {
    return _SimpleBigOptionCard(
      title: 'POS',
      icon: Icons.point_of_sale_rounded,
      accentColor: const Color(0xFF0D9488),
      gradientColors: const [Color(0xFF0D9488), Color(0xFF0F766E)],
      onTap: () => _navigateToTab(CashierNavTab.pos),
    );
  }

  // ── Card 2: Admin Dashboard (Back-Office) ──
  Widget _buildDashboardCard({required bool isKiosk}) {
    return _SimpleBigOptionCard(
      title: 'Dashboard',
      icon: Icons.dashboard_customize_rounded,
      accentColor: const Color(0xFF0F172A),
      gradientColors: const [Color(0xFF1E293B), Color(0xFF0F172A)],
      onTap: () => _navigateToTab(CashierNavTab.dashboard),
    );
  }
}

class _SimpleBigOptionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _SimpleBigOptionCard({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  State<_SimpleBigOptionCard> createState() => _SimpleBigOptionCardState();
}

class _SimpleBigOptionCardState extends State<_SimpleBigOptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _isHovered ? widget.accentColor : const Color(0xFFE2E8F0),
              width: _isHovered ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? widget.accentColor.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: _isHovered ? 32 : 16,
                offset: Offset(0, _isHovered ? 14 : 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Big Icon Container
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: widget.gradientColors.first.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 54,
                ),
              ),
              const SizedBox(height: 24),
              // Big Title (POS / Dashboard)
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
