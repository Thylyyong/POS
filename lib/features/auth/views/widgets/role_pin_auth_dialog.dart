import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../models/user_model.dart';
import '../../../../core/theme/sprite_icons.dart';
import '../../../../widgets/app_svg_icon.dart';

class RolePinAuthDialog extends StatefulWidget {
  final UserModel user;
  final VoidCallback onAuthenticated;

  const RolePinAuthDialog({
    super.key,
    required this.user,
    required this.onAuthenticated,
  });

  @override
  State<RolePinAuthDialog> createState() => _RolePinAuthDialogState();
}

class _RolePinAuthDialogState extends State<RolePinAuthDialog> {
  String _pin = '';
  bool _hasError = false;
  String _errorMsg = 'Incorrect PIN code. Please try again.';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _hasError = false;
      });
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _hasError = false;
      });
    }
  }

  void _onClear() {
    setState(() {
      _pin = '';
      _hasError = false;
    });
  }

  void _verifyPin() {
    if (_pin.length != 4) return;
    if (widget.user.isLocked) {
      setState(() {
        _hasError = true;
        _errorMsg = 'This account has been locked by the owner.';
        _pin = '';
      });
      return;
    }
    if (_pin.trim() == widget.user.pinCode.trim()) {
      Navigator.of(context).pop();
      widget.onAuthenticated();
    } else {
      setState(() {
        _hasError = true;
        _errorMsg = 'Incorrect PIN code. Please try again.';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter) {
            if (_pin.length == 4) {
              _verifyPin();
            }
          } else if (key == LogicalKeyboardKey.backspace) {
            _onBackspace();
          } else if (key == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
          } else {
            final char = event.character;
            if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
              _onDigit(char);
            }
          }
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF7C3AED)
                        .withValues(alpha: 0.12),
                    child: const AppSvgIcon.sprite(
                      SpriteIcons.lock,
                      color: Color(0xFF7C3AED),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Text(
                          'Enter Security PIN & Tap Confirm',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon.sprite(
                      SpriteIcons.close,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // PIN Dots Display (4 digits)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasError
                          ? const Color(0xFFEF4444)
                          : (filled
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFE2E8F0)),
                    ),
                  );
                }),
              ),
              if (_hasError) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMsg,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Number Keypad
              _buildKeypad(),

              const SizedBox(height: 18),

              // Explicit Confirm Button (enabled only when exactly 4 digits entered)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _pin.length == 4 ? _verifyPin : null,
                  icon: const Icon(Icons.check_circle_rounded, size: 20),
                  label: const Text(
                    'Confirm & Sign In',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['1', '2', '3'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['4', '5', '6'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['7', '8', '9'].map((d) => _buildKeypadButton(d)).toList(),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSpecialKeypadButton('C', _onClear),
            _buildKeypadButton('0'),
            _buildSpecialKeypadButton('⌫', _onBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String digit) {
    return InkWell(
      onTap: () => _onDigit(digit),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 72,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
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

  Widget _buildSpecialKeypadButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 72,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
