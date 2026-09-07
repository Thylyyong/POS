import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../features/auth/views/widgets/role_pin_auth_dialog.dart';
import '../../models/user_model.dart';
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
    _selectedUser = AuthController.defaultUsers.last;
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
    final users = AuthController.defaultUsers;

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
                      size: 76,
                      borderRadius: 20,
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ColorTheme.neutral800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'OmniPOS Enterprise • Multi-Branch Odoo-Grade Suite',
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
                      constraints: const BoxConstraints(maxWidth: 430),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Role',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ColorTheme.neutral600,
                              ),
                            ),
                            const SizedBox(height: 7),
                            DropdownButtonFormField<UserModel>(
                              initialValue: _selectedUser,
                              isExpanded: true,
                              decoration: InputDecoration(
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: AppSvgIcon(
                                    AssetTheme.user,
                                    size: 18,
                                    color: ColorTheme.neutral600,
                                  ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              items: users.map((user) {
                                return DropdownMenuItem<UserModel>(
                                  value: user,
                                  child: Text(
                                    user.displayName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (user) {
                                if (user != null) {
                                  setState(() => _selectedUser = user);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedUser.isMainBoss
                                  ? 'Full access to POS, Dashboard, Reports & Settings'
                                  : 'Access to checkout and shared product catalog',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: ColorTheme.neutral600,
                              ),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _promptPinForUser(context, _selectedUser),
                              icon: const AppSvgIcon(
                                AssetTheme.verify,
                                size: 18,
                                color: Colors.white,
                              ),
                              label: const Text('Continue with PIN'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ColorTheme.buttonPrimary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
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
          ),
        ),
      ),
    );
  }
}
