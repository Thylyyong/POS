import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';
import '../controllers/auth_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/theme/asset_theme.dart';
import 'app_svg_icon.dart';

/// Reusable Admin PIN Code modal dialog with touchscreen keypad & physical keyboard support.
/// Enforces a 4-digit master PIN with automatic login when the 4th digit is entered.
class AdminPinDialog extends StatefulWidget {
  final String title;
  final String subtitle;

  const AdminPinDialog({
    super.key,
    this.title = 'Admin Verification',
    this.subtitle = 'Enter 4-digit master PIN code to unlock Admin controls',
  });

  /// Convenient static helper to show the dialog and return true if verified
  static Future<bool> show(
    BuildContext context, {
    String title = 'Admin Verification',
    String subtitle = 'Enter 4-digit master PIN code to unlock Admin controls',
  }) async {
    final authCtrl = context.read<AuthController>();
    if (authCtrl.isAdminAuthenticated) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AdminPinDialog(title: title, subtitle: subtitle),
    );
    return result ?? false;
  }

  @override
  State<AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<AdminPinDialog>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  String? _errorMessage;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnim = Tween<double>(
      begin: 0.0,
      end: 12.0,
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeCtrl);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKeyPress(String val) {
    if (_pin.length < 4) {
      final newPin = _pin + val;
      setState(() {
        _pin = newPin;
        _errorMessage = null;
      });
      if (newPin.length == 4) {
        _verifyPin(newPin);
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _onClear() {
    setState(() {
      _pin = '';
      _errorMessage = null;
    });
  }

  void _verifyPin(String pinToVerify) {
    final settings = context.read<SettingsController>().settings;
    final authCtrl = context.read<AuthController>();

    if (settings.verifyAdminPin(pinToVerify)) {
      authCtrl.loginAsAdmin();
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage = 'Incorrect Admin PIN. Please try again.';
        _pin = '';
      });
      _shakeCtrl.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter) {
            if (_pin.length == 4) {
              _verifyPin(_pin);
            }
          } else if (key == LogicalKeyboardKey.backspace) {
            _onBackspace();
          } else if (key == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop(false);
          } else {
            final char = event.character;
            if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
              _onKeyPress(char);
            }
          }
        }
      },
      child: Dialog(
        backgroundColor: Colors.white,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 340,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with Lock Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const AppSvgIcon(
                  AssetTheme.verify,
                  size: 26,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // 4-PIN Visual Indicator Dots
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(
                      _shakeAnim.value * (_shakeCtrl.value > 0 ? 1 : 0),
                      0,
                    ),
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _errorMessage != null
                          ? AppConfig.accentRose
                          : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? const Color(0xFF0D9488)
                              : const Color(0xFFE2E8F0),
                          border: Border.all(
                            color: isFilled
                                ? const Color(0xFF0D9488)
                                : const Color(0xFF94A3B8),
                            width: 1.5,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppConfig.accentRose,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Numeric Keypad (3x4 grid)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 270),
                child: Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    const SizedBox(height: 10),
                    _buildKeypadRow(['4', '5', '6']),
                    const SizedBox(height: 10),
                    _buildKeypadRow(['7', '8', '9']),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(
                          svgAsset: AssetTheme.close,
                          tooltip: 'Clear',
                          onTap: _onClear,
                        ),
                        _buildDigitButton('0'),
                        _buildActionButton(
                          svgAsset: AssetTheme.chevronLeft,
                          tooltip: 'Backspace',
                          onTap: _onBackspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Dialog Cancel Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    foregroundColor: const Color(0xFF64748B),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitButton(d)).toList(),
    );
  }

  Widget _buildDigitButton(String digit) {
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 62,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String svgAsset,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 62,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: AppSvgIcon(svgAsset, size: 20, color: const Color(0xFF64748B)),
        ),
      ),
    );
  }
}
