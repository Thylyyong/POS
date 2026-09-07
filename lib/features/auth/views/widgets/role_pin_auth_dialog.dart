import 'package:flutter/material.dart';

import '../../../../models/user_model.dart';

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

  void _onDigit(String digit) {
    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
        _hasError = false;
      });
      if (_pin.length == widget.user.pinCode.length) {
        _verifyPin();
      }
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
    if (_pin.trim() == widget.user.pinCode.trim()) {
      Navigator.of(context).pop();
      widget.onAuthenticated();
    } else {
      setState(() {
        _hasError = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Dialog(
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
                  child: const Icon(
                    Icons.lock_outline,
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
                      Text(
                        'Enter Security PIN (Default: ${user.pinCode})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // PIN Dots Display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(user.pinCode.length, (index) {
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
              const Text(
                'Incorrect PIN code. Please try again.',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Number Keypad
            _buildKeypad(),
          ],
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
