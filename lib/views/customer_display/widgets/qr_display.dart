import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app_config.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_svg_icon.dart';

class CfdQrDisplay extends StatelessWidget {
  final String qrData;
  final double totalAmount;
  final String currencySymbol;

  const CfdQrDisplay({
    super.key,
    required this.qrData,
    required this.totalAmount,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppConfig.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppConfig.accentCyan.withValues(alpha: 0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppConfig.accentCyan.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppSvgIcon(AssetTheme.searchQR, color: AppConfig.accentCyan, size: 36),
              SizedBox(width: 12),
              Text(
                'Scan QR to Pay',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Compatible with all mobile banking & QR wallets',
            style: TextStyle(color: AppConfig.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // QR Code Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 220.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

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
