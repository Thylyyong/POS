import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme/asset_theme.dart';
import 'app_svg_icon.dart';

class AppLogoWidget extends StatelessWidget {
  final String? logoPath;
  final double size;
  final double borderRadius;
  final String? fallbackSvg;
  final IconData? fallbackIcon;
  final List<BoxShadow>? boxShadow;

  const AppLogoWidget({
    super.key,
    this.logoPath,
    this.size = 48,
    this.borderRadius = 12,
    this.fallbackSvg,
    this.fallbackIcon,
    this.boxShadow,
  });

  bool get _hasAssetLogo =>
      logoPath != null &&
      logoPath!.trim().isNotEmpty &&
      logoPath!.trim().startsWith('assets/');

  bool get _hasFileLogo =>
      logoPath != null &&
      logoPath!.trim().isNotEmpty &&
      !logoPath!.trim().startsWith('assets/');

  ImageProvider? get _imageProvider {
    if (_hasAssetLogo) {
      return AssetImage(logoPath!.trim());
    }
    if (_hasFileLogo) {
      return FileImage(File(logoPath!.trim()));
    }
    return null;
  }

  Widget _buildFallback() {
    return Center(
      child: AppSvgIcon(
        fallbackSvg ?? AssetTheme.store,
        size: size * 0.55,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _imageProvider;
    final hasImage = imageProvider != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hasImage ? Colors.transparent : const Color(0xFF0F172A),
        gradient: !hasImage
            ? const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: hasImage
            ? Image(
                image: imageProvider,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: _buildFallback(),
                  );
                },
              )
            : _buildFallback(),
      ),
    );
  }
}
