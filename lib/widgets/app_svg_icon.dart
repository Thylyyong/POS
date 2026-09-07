import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppSvgIcon extends StatelessWidget {
  final String asset;
  final double? size;
  final double? width;
  final double? height;
  final Color? color;
  final BoxFit fit;

  /// SVGs from storex_customer have generous viewport margin padding (~20-25% empty margin)
  /// and fine 1.4px outline strokes. An optical scaling factor of 1.28x ensures
  /// they have strong visual weight, clarity, and parity with standard UI icons.
  static const double opticalScale = 1.28;

  const AppSvgIcon(
    this.asset, {
    super.key,
    this.size = 22.0,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final rawW = width ?? size ?? 22.0;
    final rawH = height ?? size ?? 22.0;
    final effectiveWidth = rawW * opticalScale;
    final effectiveHeight = rawH * opticalScale;

    return SvgPicture.asset(
      asset,
      width: effectiveWidth,
      height: effectiveHeight,
      fit: fit,
      colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );
  }
}
