import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/theme/asset_theme.dart';
import '../../core/device_profile.dart';
import '../../models/user_model.dart';
import '../../widgets/app_logo_widget.dart';
import '../../widgets/app_svg_icon.dart';
import '../cashier/cashier_main_layout.dart';
import '../cashier/widgets/nav_sidebar.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key});

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  bool _isSubmitting = false;
  String? _errorMessage;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_isSubmitting || _enteredPin.length >= 4) return;
    setState(() {
      _errorMessage = null;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_isSubmitting || _enteredPin.isEmpty) return;
    setState(() {
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _onClear() {
    if (_isSubmitting) return;
    setState(() {
      _errorMessage = null;
      _enteredPin = '';
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthController>();
    final user = await auth.loginWithPin(_enteredPin);

    if (!mounted) return;

    if (user != null) {
      // Route based on enterprise role
      _routeUserToDashboard(user);
    } else {
      _shakeCtrl.forward(from: 0.0);
      HapticFeedback.heavyImpact();
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Invalid PIN code. Please try again.';
        _enteredPin = '';
      });
    }
  }

  void _loginAsCashierDirectly() {
    final auth = context.read<AuthController>();
    auth.loginAsCashier();
    _routeUserToDashboard(auth.currentUser);
  }

  void _routeUserToDashboard(UserModel user) {
    if (user.isOwner) {
      // OWNER / BOSS -> routes to full analytics dashboard with all tabs
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const CashierMainLayout(initialTab: CashierNavTab.dashboard),
        ),
      );
    } else {
      // STAFF CASHIER -> routes to POS Register
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const CashierMainLayout(initialTab: CashierNavTab.pos),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    final storeName = settings.storeName;
    final logoPath = settings.logoPath;

    final isKiosk = DeviceProfile.isKiosk(
      context,
      deviceProfile: settings.deviceProfile,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate enterprise theme
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: isKiosk
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildBrandSection(storeName, logoPath, isKiosk),
                      const SizedBox(height: 28),
                      _buildNumpadSection(isKiosk),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildBrandSection(storeName, logoPath, isKiosk),
                      const SizedBox(width: 56),
                      _buildNumpadSection(isKiosk),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandSection(String storeName, String? logoPath, bool isKiosk) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isKiosk ? 580 : 420),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment:
            isKiosk ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          // Brand Logo
          AppLogoWidget(
            logoPath: logoPath,
            size: isKiosk ? 96 : 72,
            borderRadius: 20,
            fallbackSvg: AssetTheme.store,
          ),
          const SizedBox(height: 16),

          Text(
            storeName.toUpperCase(),
            textAlign: isKiosk ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: Colors.white,
              fontSize: isKiosk ? 30 : 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'OmniPOS Enterprise System • Role-Based Access',
            textAlign: isKiosk ? TextAlign.center : TextAlign.start,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),

          // Offline Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvgIcon(AssetTheme.flash, size: 14, color: Color(0xFF38BDF8)),
                SizedBox(width: 6),
                Text(
                  '100% OFFLINE-READY • LOCAL SQLITE ACTIVE',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Employee Quick Guide Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AVAILABLE ACCESS PROFILES',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                _buildRoleItem(
                  roleTitle: 'STAFF CASHIER',
                  subtitle: 'Frontline POS, Cart, Tables & Receipts',
                  tag: 'NO PIN NEEDED',
                  tagColor: const Color(0xFF10B981),
                ),
                const Divider(color: Color(0xFF334155), height: 16),
                _buildRoleItem(
                  roleTitle: 'OWNER / ADMIN (BOSS)',
                  subtitle: 'Full Access (Reports, P&L, Settings)',
                  tag: 'PIN: ****',
                  tagColor: const Color(0xFF0D9488),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumpadSection(bool isKiosk) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isKiosk ? 500 : 400),
      child: Container(
        padding: EdgeInsets.all(isKiosk ? 30 : 24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF334155)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Instant 1-Tap Cashier Login
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loginAsCashierDirectly,
                icon: const Icon(Icons.point_of_sale, size: 20, color: Colors.white),
                label: const Text(
                  'Login as Staff Cashier (No PIN Required)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Divider
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFF334155))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR OWNER / ADMIN PIN',
                    style: TextStyle(
                      color: const Color(0xFF94A3B8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFF334155))),
              ],
            ),
            const SizedBox(height: 14),

            // PIN Dot Indicators with Shake Animation
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (idx) {
                  final isFilled = idx < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? const Color(0xFF14B8A6)
                          : const Color(0xFF0F172A),
                      border: Border.all(
                        color: isFilled
                            ? const Color(0xFF14B8A6)
                            : const Color(0xFF475569),
                        width: 2,
                      ),
                      boxShadow: [
                        if (isFilled)
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),

            // Error Message
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFF87171),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const SizedBox(height: 16),

            const SizedBox(height: 8),

            // On-Screen Numeric Keypad (4x3)
            _buildNumpadGrid(isKiosk),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleItem({
    required String roleTitle,
    required String subtitle,
    required String tag,
    required Color tagColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                roleTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: tagColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: tagColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: tagColor,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpadGrid(bool isKiosk) {
    final buttons = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: buttons.map((row) {
        return Padding(
          padding: EdgeInsets.only(bottom: isKiosk ? 12 : 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((btn) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: isKiosk ? 8 : 6),
                child: _buildNumpadButton(btn, isKiosk),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumpadButton(String val, bool isKiosk) {
    final isClear = val == 'C';
    final isBackspace = val == '⌫';
    final isAction = isClear || isBackspace;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isClear) {
            _onClear();
          } else if (isBackspace) {
            _onBackspace();
          } else {
            _onDigitPressed(val);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: isKiosk ? 96 : 78,
          height: isKiosk ? 76 : 60,
          decoration: BoxDecoration(
            color: isAction ? const Color(0xFF0F172A) : const Color(0xFF334155),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAction
                  ? const Color(0xFF475569)
                  : const Color(0xFF475569).withValues(alpha: 0.5),
            ),
          ),
          child: Center(
            child: Text(
              val,
              style: TextStyle(
                color: isClear
                    ? const Color(0xFFF87171)
                    : (isBackspace ? const Color(0xFF38BDF8) : Colors.white),
                fontSize: isKiosk ? 26 : 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
