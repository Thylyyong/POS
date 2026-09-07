import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/color_theme.dart';

/// Custom POS Scroll Behavior: Removes the "gummy/stretchy" overscroll distortion
/// and provides crisp, solid clamping scroll physics for commercial POS touchscreens & desktop.
class PosCustomScrollBehavior extends MaterialScrollBehavior {
  const PosCustomScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: ColorTheme.buttonPrimary.withValues(alpha: 0.2),
      child: child,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
