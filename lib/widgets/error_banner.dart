import 'dart:async';
import 'package:flutter/material.dart';
import '../app_config.dart';
import '../core/theme/asset_theme.dart';
import 'app_svg_icon.dart';

/// Slim animated error banner that appears at the top of a view when an
/// error string is non-null, and self-dismisses after [autoDismiss].
class ErrorBanner extends StatefulWidget {
  final String message;
  final VoidCallback? onDismiss;
  final Duration autoDismiss;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.autoDismiss = const Duration(seconds: 5),
  });

  @override
  State<ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<ErrorBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _slideAnim;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _animCtrl.forward();
    _dismissTimer = Timer(widget.autoDismiss, _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _animCtrl.reverse().then((_) {
      if (mounted) widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _slideAnim,
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppConfig.accentRose.withValues(alpha: 0.92),
        child: Row(
          children: [
            const AppSvgIcon(AssetTheme.clearWarning, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: _dismiss,
              child: const AppSvgIcon(AssetTheme.close, color: Colors.white70, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
