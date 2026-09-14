import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app_config.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_logo_widget.dart';
import '../../../widgets/app_svg_icon.dart';

class CfdQrDisplay extends StatelessWidget {
  final String qrData;
  final double totalAmount;
  final String currencySymbol;
  final String? storeName;
  final String? logoPath;
  final String? qrImagePath;

  const CfdQrDisplay({
    super.key,
    required this.qrData,
    required this.totalAmount,
    required this.currencySymbol,
    this.storeName,
    this.logoPath,
    this.qrImagePath,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = qrImagePath != null && qrImagePath!.isNotEmpty && File(qrImagePath!).existsSync();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D9488).withValues(alpha: 0.1),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Store Branding at Top
          if (logoPath != null || storeName != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogoWidget(
                  logoPath: logoPath,
                  size: 40,
                  borderRadius: 8,
                  fallbackSvg: AssetTheme.store,
                ),
                if (storeName != null && storeName!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text(
                    storeName!,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Title
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvgIcon(AssetTheme.searchQR, color: Color(0xFF0D9488), size: 24),
              SizedBox(width: 8),
              Text(
                'Scan QR to Pay',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Compatible with all mobile banking & QR wallets',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 16),

          // QR Code Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(qrImagePath!),
                      width: 280.0,
                      height: 280.0,
                      fit: BoxFit.contain,
                    ),
                  )
                : QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 280.0,
                    backgroundColor: Colors.white,
                  ),
          ),
          const SizedBox(height: 16),

          // Total Amount Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppConfig.primaryDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'AMOUNT DUE: ',
                  style: TextStyle(color: AppConfig.textSecondary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$currencySymbol${totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppConfig.accentCyan,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
