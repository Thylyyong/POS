import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../features/auth/views/widgets/role_pin_auth_dialog.dart';
import '../../models/user_model.dart';
import '../../core/device_profile.dart';
import '../../widgets/app_logo_widget.dart';
import '../../core/theme/asset_theme.dart';
import '../../widgets/app_svg_icon.dart';
import '../cashier/cashier_main_layout.dart';
import '../cashier/widgets/nav_sidebar.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late UserModel _selectedUser;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _selectedUser = AuthController.screenUsers.last;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _promptPinForUser(BuildContext context, UserModel user) {
    if (!user.isOwner) {
      final auth = context.read<AuthController>();
      auth.loginAsCashier();
      _navigateToLayout(context, CashierNavTab.pos);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RolePinAuthDialog(
        user: user,
        onAuthenticated: () {
          final auth = context.read<AuthController>();
          auth.loginWithUserAndPin(user, user.pinCode);

          if (user.isMainBoss || user.isSubBoss) {
            _navigateToLayout(context, CashierNavTab.dashboard);
          } else {
            _navigateToLayout(context, CashierNavTab.pos);
          }
        },
      ),
    );
  }

  void _navigateToLayout(BuildContext context, CashierNavTab tab) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => CashierMainLayout(initialTab: tab),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsCtrl = context.watch<SettingsController>();
    final storeName = settingsCtrl.settings.storeName;
    final logoPath = settingsCtrl.settings.logoPath;

    final isKiosk = DeviceProfile.isKiosk(
      context,
      deviceProfile: settingsCtrl.settings.deviceProfile,
    );
    final logoSize = isKiosk ? 104.0 : 76.0;
    final titleSize = isKiosk ? 30.0 : 24.0;
    final cardMaxWidth = isKiosk ? 640.0 : 430.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Logo
                    AppLogoWidget(
                      logoPath: logoPath,
                      size: logoSize,
                      borderRadius: isKiosk ? 24 : 20,
                      fallbackSvg: AssetTheme.store,
                      boxShadow: [
                        BoxShadow(
                          color: ColorTheme.buttonPrimary.withValues(
                            alpha: 0.2,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // App Title & Store Name
                    Text(
                      storeName.toUpperCase(),
                      style: TextStyle(
                        fontSize: titleSize,
                        fontWeight: FontWeight.bold,
                        color: ColorTheme.neutral800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'OmniPOS Enterprise • Multi-Branch POS Suite',
                      style: TextStyle(
                        fontSize: 13,
                        color: ColorTheme.neutral600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 100% Offline Ready Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppSvgIcon(
                            AssetTheme.flash,
                            size: 13,
                            color: Color(0xFF0284C7),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '100% OFFLINE READY • DUAL-SCREEN & CASH DRAWER ACTIVE',
                            style: TextStyle(
                              color: Color(0xFF0284C7),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Login panel
                    const Text(
                      'SIGN IN TO OMNI POS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cardMaxWidth,
                      ),
                      child: Container(
                        padding: EdgeInsets.all(isKiosk ? 36 : 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'SELECT ROLE TO SIGN IN',
                              style: TextStyle(
                                fontSize: isKiosk ? 14 : 11.5,
                                fontWeight: FontWeight.bold,
                                color: ColorTheme.neutral600,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Role Selection Cards
                            Row(
                              children: [
                                // Staff Cashier Card
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedUser = AuthController.screenUsers.last;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      padding: EdgeInsets.all(isKiosk ? 18 : 14),
                                      decoration: BoxDecoration(
                                        color: !_selectedUser.isOwner
                                            ? const Color(0xFF0D9488)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: !_selectedUser.isOwner
                                              ? const Color(0xFF0D9488)
                                              : const Color(0xFFE2E8F0),
                                          width: !_selectedUser.isOwner ? 2 : 1.2,
                                        ),
                                        boxShadow: !_selectedUser.isOwner
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF0D9488).withValues(alpha: 0.25),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.point_of_sale_rounded,
                                            size: isKiosk ? 30 : 24,
                                            color: !_selectedUser.isOwner
                                                ? Colors.white
                                                : const Color(0xFF0D9488),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Staff Cashier',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: isKiosk ? 16 : 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: !_selectedUser.isOwner
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Boss (Owner) Card
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedUser = AuthController.screenUsers.first;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      padding: EdgeInsets.all(isKiosk ? 18 : 14),
                                      decoration: BoxDecoration(
                                        color: _selectedUser.isOwner
                                            ? const Color(0xFF0F172A)
                                            : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: _selectedUser.isOwner
                                              ? const Color(0xFF0F172A)
                                              : const Color(0xFFE2E8F0),
                                          width: _selectedUser.isOwner ? 2 : 1.2,
                                        ),
                                        boxShadow: _selectedUser.isOwner
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.18),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ]
                                            : [],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.admin_panel_settings_rounded,
                                            size: isKiosk ? 30 : 24,
                                            color: _selectedUser.isOwner
                                                ? Colors.white
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Boss (Owner)',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: isKiosk ? 16 : 13.5,
                                              fontWeight: FontWeight.bold,
                                              color: _selectedUser.isOwner
                                                  ? Colors.white
                                                  : const Color(0xFF0F172A),
                                            ),
                                          ),
                                         
                                          
                                          
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Role Description Subtitle
                            Text(
                              !_selectedUser.isOwner
                                  ? 'Instant frontline POS checkout'
                                  : 'Full access to POS, P&L Accounting, Reports & Settings',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isKiosk ? 13 : 11.5,
                                color: ColorTheme.neutral600,
                              ),
                            ),
                            SizedBox(height: isKiosk ? 22 : 16),

                            // Main Action Login Button
                            if (!_selectedUser.isOwner)
                              ElevatedButton.icon(
                                onPressed: () {
                                  final auth = context.read<AuthController>();
                                  auth.loginAsCashier();
                                  _navigateToLayout(context, CashierNavTab.pos);
                                },
                                icon: const Icon(
                                  Icons.bolt_rounded,
                                  size: 22,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Login as Staff Cashier ',
                                  style: TextStyle(
                                    fontSize: isKiosk ? 16 : 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0D9488),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isKiosk ? 20 : 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              )
                            else
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _promptPinForUser(context, _selectedUser),
                                icon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 20,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Continue with PIN',
                                  style: TextStyle(
                                    fontSize: isKiosk ? 16 : 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isKiosk ? 20 : 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Device Profile Status Indicator Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isKiosk
                                ? Icons.stay_current_portrait
                                : Icons.desktop_windows,
                            size: 14,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isKiosk
                                ? 'Profile: CA H2 Kiosk (21.5" Portrait)'
                                : 'Profile: POS CA9 (15.6" Landscape)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
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
    );
  }
}
