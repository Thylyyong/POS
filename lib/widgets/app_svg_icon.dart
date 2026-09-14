import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/theme/asset_theme.dart';
import '../services/svg_sprite_service.dart';

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

  /// Explicit constructor for icons defined in `sprite.svg`
  const AppSvgIcon.sprite(
    String iconId, {
    super.key,
    this.size = 22.0,
    this.width,
    this.height,
    this.color,
    this.fit = BoxFit.contain,
  }) : asset = iconId;

  @override
  Widget build(BuildContext context) {
    final rawW = width ?? size ?? 22.0;
    final rawH = height ?? size ?? 22.0;
    final effectiveWidth = rawW * opticalScale;
    final effectiveHeight = rawH * opticalScale;
    final colorFilter = color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null;

    // 1. Try finding in SvgSpriteService directly (by ID, e.g. "icon-pos", or short name "pos")
    final spriteService = SvgSpriteService.instance;
    var svgString = spriteService.getSvg(asset);

    // 2. If not found, check if this is a mapped legacy asset path
    if (svgString == null && AssetTheme.legacyToSprite.containsKey(asset)) {
      final spriteId = AssetTheme.legacyToSprite[asset]!;
      svgString = spriteService.getSvg(spriteId);
    }

    // 3. Render from sprite if available
    if (svgString != null) {
      return SvgPicture.string(
        svgString,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        colorFilter: colorFilter,
      );
    }

    // 4. Fallback to asset file (if ends with .svg or contains /)
    if (asset.endsWith('.svg') || asset.contains('/')) {
      return SvgPicture.asset(
        asset,
        width: effectiveWidth,
        height: effectiveHeight,
        fit: fit,
        colorFilter: colorFilter,
      );
    }

    // 5. If not found in sprite and not an asset path, attempt lazy initialize & return fallback
    if (!spriteService.isInitialized) {
      spriteService.initialize();
    }

    return SizedBox(
      width: effectiveWidth,
      height: effectiveHeight,
    );
  }
}
