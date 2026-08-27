import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/settings_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../services/presentation_service.dart';
import '../../../widgets/app_logo_widget.dart';
import '../../customer_display/customer_main_view.dart';

class TopHeaderBar extends StatelessWidget {
  const TopHeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StoreNameBadge(),
          _HardwareStatusBadges(),
        ],
      ),
    );
  }
}

class _StoreNameBadge extends StatelessWidget {
  const _StoreNameBadge();

  @override
  Widget build(BuildContext context) {
    final settings = context.select<SettingsController, dynamic>(
      (c) => c.settings,
    );
    final storeName = settings.storeName as String;
    final logoPath = settings.logoPath as String?;

    return Row(
      children: [
        AppLogoWidget(
          logoPath: logoPath,
          size: 32,
          borderRadius: 8,
          fallbackIcon: Icons.storefront,
        ),
        const SizedBox(width: 10),
        Text(
          storeName,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 17,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppConfig.accentGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppConfig.accentGreen.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, color: AppConfig.accentGreenDark, size: 12),
              SizedBox(width: 4),
              Text(
                '100% OFFLINE POS',
                style: TextStyle(
                  color: AppConfig.accentGreenDark,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HardwareStatusBadges extends StatelessWidget {
  const _HardwareStatusBadges();

  @override
  Widget build(BuildContext context) {
    final cfdEnabled = context.select<SettingsController, bool>(
      (c) => c.settings.cfdEnabled,
    );
    final is80mm = context.select<SettingsController, bool>(
      (c) => c.settings.isPaperSize80mm,
    );
    final scanNotice = context.select<PosController, String?>(
      (c) => c.scannedBarcodeNotice,
    );

    return Row(
      children: [
        // Duplicate / Launch Screen Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConfig.accentCyan,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          onPressed: () async {
            // Trigger dual-screen presentation cast on physical device
            await PresentationService().showCustomerDisplay();

            // Also open preview on cashier screen
            if (context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerMainView()),
              );
            }
          },
          icon: const Icon(Icons.screen_share, size: 16),
          label: const Text(
            'Duplicate Screen',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        _CfdBadge(enabled: cfdEnabled),
        const SizedBox(width: 8),
        _PrinterBadge(is80mm: is80mm),
        const SizedBox(width: 8),
        _ScannerBadge(notice: scanNotice),
      ],
    );
  }
}

class _CfdBadge extends StatelessWidget {
  final bool enabled;
  const _CfdBadge({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await PresentationService().showCustomerDisplay();
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CustomerMainView()),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: enabled
              ? AppConfig.accentCyan.withValues(alpha: 0.12)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? AppConfig.accentCyan.withValues(alpha: 0.4) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tv,
              size: 14,
              color: enabled ? AppConfig.accentCyan : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              enabled ? 'CFD ACTIVE' : 'CFD OFF',
              style: TextStyle(
                color: enabled ? AppConfig.accentCyan : const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrinterBadge extends StatelessWidget {
  final bool is80mm;
  const _PrinterBadge({required this.is80mm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.all(Radius.circular(8)),
        border: Border.fromBorderSide(BorderSide(color: Color(0xFFCBD5E1))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.print, size: 14, color: AppConfig.accentGreenDark),
          const SizedBox(width: 6),
          Text(
            is80mm ? '80mm Thermal' : '58mm Thermal',
            style: const TextStyle(
              color: Color(0xFF334155),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerBadge extends StatelessWidget {
  final String? notice;
  const _ScannerBadge({this.notice});

  @override
  Widget build(BuildContext context) {
    final isActive = notice != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? AppConfig.accentGreen.withValues(alpha: 0.12)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppConfig.accentGreen : const Color(0xFFCBD5E1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 14,
            color: isActive ? AppConfig.accentGreenDark : const Color(0xFF64748B),
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? notice! : 'SCANNER READY',
            style: TextStyle(
              color: isActive ? AppConfig.accentGreenDark : const Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
