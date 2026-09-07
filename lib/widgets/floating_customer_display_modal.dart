import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/presentation_service.dart';
import '../views/customer_display/customer_main_view.dart';
import '../core/theme/asset_theme.dart';
import 'app_svg_icon.dart';

/// Interactive Live Dual-Screen Modal & Floating Window.
/// Displays the real-time Customer-Facing Display (CFD) alongside the Cashier Screen.
class FloatingCustomerDisplayModal extends StatelessWidget {
  const FloatingCustomerDisplayModal({super.key});

  /// Displays the interactive Dual-Screen modal dialog
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const FloatingCustomerDisplayModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = (size.width * 0.7).clamp(650.0, 1000.0);
    final dialogHeight = (size.height * 0.78).clamp(480.0, 720.0);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 20,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // ── Top Dual-Screen Header Control Bar ──────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(bottom: BorderSide(color: Color(0xFF334155))),
              ),
              child: Row(
                children: [
                  const AppSvgIcon(AssetTheme.video, color: AppConfig.accentCyan, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Customer-Facing Display',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Live Indicator Tag
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              borderRadius: BorderRadius.all(Radius.circular(4)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'LIVE DUAL-SCREEN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Mirroring live cart, totals, and QR payments in real time',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Launch 2nd Monitor OS Window Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFF475569)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final launched = await PresentationService().launchSecondaryWindow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              launched
                                  ? 'Opened separate Customer Display Window on 2nd monitor!'
                                  : 'Customer Display active',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const AppSvgIcon(AssetTheme.refer, size: 15, color: AppConfig.accentCyan),
                    label: const Text('Open in 2nd Monitor Window', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 10),

                  // Close Dialog Button
                  IconButton(
                    icon: const AppSvgIcon(AssetTheme.close, color: Colors.white, size: 18),
                    tooltip: 'Close Preview',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Embedded Live Customer Screen ───────────────────────────────
            const Expanded(
              child: CustomerMainView(),
            ),
          ],
        ),
      ),
    );
  }
}
