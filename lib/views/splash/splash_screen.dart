import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_config.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../widgets/admin_pin_dialog.dart';
import '../../widgets/app_logo_widget.dart';
import '../cashier/cashier_main_layout.dart';
import '../cashier/widgets/nav_sidebar.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _launchPosMode(BuildContext context) {
    // POS mode launches immediately with NO PIN code required
    context.read<AuthController>().loginAsCashier();
    _navigateToLayout(context, CashierNavTab.pos);
  }

  Future<void> _launchDashboardMode(BuildContext context) async {
    // Dashboard mode requires master Admin PIN code
    final verified = await AdminPinDialog.show(
      context,
      title: 'Admin Verification',
      subtitle: 'Enter master PIN code to unlock Analytics Dashboard and Admin controls',
    );

    if (verified && context.mounted) {
      _navigateToLayout(context, CashierNavTab.dashboard);
    }
  }

  void _navigateToLayout(BuildContext context, CashierNavTab tab) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Logo with Emerald Gradient Glow or Store Profile Image
                    AppLogoWidget(
                      logoPath: logoPath,
                      size: 84,
                      borderRadius: 24,
                      fallbackIcon: Icons.point_of_sale,
                      boxShadow: [
                        BoxShadow(
                          color: ColorTheme.buttonPrimary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // App Title & Store Name
                    Text(
                      storeName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: ColorTheme.neutral800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enterprise Offline Dual-Screen Point of Sale',
                      style: TextStyle(fontSize: 14, color: ColorTheme.neutral600, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),

                    // Offline Ready Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: ColorTheme.neutral100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: ColorTheme.neutral300),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, size: 14, color: ColorTheme.primary400),
                          SizedBox(width: 6),
                          Text(
                            '100% OFFLINE READY • DUAL-SCREEN ENABLED',
                            style: TextStyle(
                              color: ColorTheme.primary400,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Select Workspace / Launch Mode Prompt
                    const Text(
                      'SELECT LAUNCH MODE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: ColorTheme.neutral500,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Two Primary Launch Mode Cards
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
                      child: Row(
                        children: [
                          // 1. POS MODE CARD
                          Expanded(
                            child: _buildModeCard(
                              context: context,
                              title: 'Point of Sale (POS)',
                              subtitle: 'Cashier terminal, menu catalog, table assignments, and checkout (No PIN required)',
                              icon: Icons.storefront,
                              accentColor: ColorTheme.buttonPrimary,
                              buttonLabel: 'Launch POS Mode',
                              onTap: () => _launchPosMode(context),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // 2. DASHBOARD MODE CARD
                          Expanded(
                            child: _buildModeCard(
                              context: context,
                              title: 'Analytics Dashboard',
                              subtitle: 'Gross revenue, live sales spreadsheet, KPI charts, and Excel reports (Admin PIN protected)',
                              icon: Icons.insights,
                              accentColor: AppConfig.accentCyan,
                              buttonLabel: 'Launch Dashboard',
                              onTap: () => _launchDashboardMode(context),
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

  Widget _buildModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
