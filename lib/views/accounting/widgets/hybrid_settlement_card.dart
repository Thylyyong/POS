import 'package:flutter/material.dart';

import '../../../controllers/auth_controller.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../models/accounting_model.dart';
import '../../../widgets/app_svg_icon.dart';

class HybridSettlementCard extends StatelessWidget {
  final ProfitLossReportModel report;
  final AuthController auth;

  const HybridSettlementCard({
    super.key,
    required this.report,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    if (report.isConsolidated) {
      final totalInflow =
          report.totalRentCollected + report.totalRoyaltiesCollected;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const AppSvgIcon(
                AssetTheme.store,
                color: Color(0xFF0F172A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Franchise Inflow from Store Branches',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Base Rent Collected: \$ ${report.totalRentCollected.toStringAsFixed(2)}  •  Sales Royalties (3%): \$ ${report.totalRoyaltiesCollected.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Text(
                '+ \$ ${totalInflow.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF059669),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const AppSvgIcon(
                AssetTheme.wallet,
                color: Color(0xFF0F172A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Franchise Settlement to Main Boss (${report.branchName})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fixed Rent: \$ ${report.baseRentPaidToMainBoss.toStringAsFixed(2)}  •  3.0% Sales Royalty: \$ ${report.salesRoyaltyPaidToMainBoss.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Text(
                '- \$ ${report.totalHybridSettlementToMainBoss.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
}
