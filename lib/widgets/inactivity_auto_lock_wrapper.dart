import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../views/splash/splash_screen.dart';

class InactivityAutoLockWrapper extends StatefulWidget {
  final Widget child;
  final Duration timeout;
  final bool enabled;

  const InactivityAutoLockWrapper({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 5),
    this.enabled = true,
  });

  static InactivityAutoLockWrapperState? of(BuildContext context) {
    return context.findAncestorStateOfType<InactivityAutoLockWrapperState>();
  }

  @override
  State<InactivityAutoLockWrapper> createState() =>
      InactivityAutoLockWrapperState();
}

class InactivityAutoLockWrapperState extends State<InactivityAutoLockWrapper> {
  Timer? _idleTimer;
  bool _isLocked = false;
  bool get isLocked => _isLocked;

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _idleTimer?.cancel();
    if (!widget.enabled || _isLocked) return;

    _idleTimer = Timer(widget.timeout, () {
      if (mounted && !_isLocked) {
        final auth = context.read<AuthController>();
        // Only lock if someone is logged in and not on splash screen
        if (auth.isAdminAuthenticated || auth.currentUser.id.isNotEmpty) {
          lockNow();
        }
      }
    });
  }

  void lockNow() {
    setState(() {
      _isLocked = true;
    });
    _idleTimer?.cancel();
  }

  void unlock() {
    setState(() {
      _isLocked = false;
    });
    _resetTimer();
  }

  void _onUserInteraction([_]) {
    if (!_isLocked) {
      _resetTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onUserInteraction,
      onPointerMove: _onUserInteraction,
      onPointerHover: _onUserInteraction,
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          widget.child,
          if (_isLocked)
            Positioned.fill(
              child: _LockOverlay(
                onUnlocked: unlock,
                onSwitchUser: () {
                  unlock();
                  final auth = context.read<AuthController>();
                  auth.logout();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SplashScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LockOverlay extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onSwitchUser;

  const _LockOverlay({required this.onUnlocked, required this.onSwitchUser});

  @override
  State<_LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<_LockOverlay> {
  String _pin = '';
  bool _hasError = false;

  void _onDigit(String digit, String expectedPin) {
    if (_pin.length < 6) {
      setState(() {
        _pin += digit;
        _hasError = false;
      });
      if (_pin.length >= expectedPin.length) {
        _verifyPin(expectedPin);
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

  void _verifyPin(String expectedPin) {
    // Also accept Master Admin PIN (9999 or 123456)
    if (_pin.trim() == expectedPin.trim() ||
        _pin.trim() == '9999' ||
        _pin.trim() == '123456') {
      widget.onUnlocked();
    } else {
      setState(() {
        _hasError = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final expectedPin = user.pinCode;

    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lock Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Center(
                  child: Icon(
                    Icons.lock_rounded,
                    size: 26,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Terminal Locked',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Inactive for 5 mins • Unlock as ${user.displayName}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // PIN Masked Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  expectedPin.length.clamp(4, 6),
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length
                          ? (_hasError
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF0D9488))
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ),
              if (_hasError) ...[
                const SizedBox(height: 8),
                const Text(
                  'Incorrect PIN. Please try again.',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Touch Numpad (1-9, CLR, 0, Backspace)
              _buildNumpad(expectedPin),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 8),

              // Switch User / Logout button
              TextButton.icon(
                onPressed: widget.onSwitchUser,
                icon: const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                label: const Text(
                  'Switch User / Log Out',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad(String expectedPin) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['CLR', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: 64,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: key == 'CLR' || key == '⌫'
                          ? const Color(0xFFF1F5F9)
                          : Colors.white,
                      foregroundColor: key == 'CLR' || key == '⌫'
                          ? const Color(0xFF475569)
                          : const Color(0xFF0F172A),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () {
                      if (key == 'CLR') {
                        _onClear();
                      } else if (key == '⌫') {
                        _onBackspace();
                      } else {
                        _onDigit(key, expectedPin);
                      }
                    },
                    child: Text(
                      key,
                      style: TextStyle(
                        fontSize: key == 'CLR' ? 12 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
