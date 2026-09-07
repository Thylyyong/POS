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
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF5FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE9D5FF)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const AppSvgIcon(
                AssetTheme.store,
                color: Color(0xFF7C3AED),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      AppSvgIcon(
                        AssetTheme.verify,
                        color: Color(0xFF581C87),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Main Boss Executive Franchise Inflow',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF581C87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total Base Rent Collected: \$ ${report.totalRentCollected.toStringAsFixed(2)}  •  Product Sales Royalties: \$ ${report.totalRoyaltiesCollected.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B21A8),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '+ \$ ${(report.totalRentCollected + report.totalRoyaltiesCollected).toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const AppSvgIcon(
                AssetTheme.payment,
                color: Color(0xFF059669),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AppSvgIcon(
                        AssetTheme.wallet,
                        color: Color(0xFF14532D),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Hybrid Settlement to Main Boss (${report.branchName})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF14532D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fixed Low Rent (\$ ${report.baseRentPaidToMainBoss.toStringAsFixed(2)}) + 3.0% Product Royalty (\$ ${report.salesRoyaltyPaidToMainBoss.toStringAsFixed(2)})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '- \$ ${report.totalHybridSettlementToMainBoss.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      );
    }
  }
}
