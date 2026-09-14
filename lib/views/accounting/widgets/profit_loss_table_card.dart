import 'package:flutter/material.dart';

import '../../../core/theme/sprite_icons.dart';
import '../../../widgets/app_svg_icon.dart';
import '../../../models/accounting_model.dart';

class ProfitLossTableCard extends StatelessWidget {
  final ProfitLossReportModel report;

  const ProfitLossTableCard({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // P&L Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report Category',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  'Balance',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),

          // 1. REVENUE SECTION
          _buildCategoryHeader('Revenue & Sales', SpriteIcons.trendingUp, const Color(0xFF0F172A)),
          _buildLineItem('Product Sales', report.grossSalesRevenue, isPrimary: true),
          _buildLineItem(
            'Cost of Goods Sold (Ingredients & Inventory)',
            -report.costOfSales,
            indent: true,
          ),
          _buildTotalRow(
            'Gross Profit',
            report.grossProfit,
            badge: report.grossSalesRevenue > 0
                ? '${((report.grossProfit / report.grossSalesRevenue) * 100).toStringAsFixed(1)}% Margin'
                : null,
            badgeColor: const Color(0xFF0D9488),
          ),

          const SizedBox(height: 6),

          // 2. EXPENSE SECTION
          _buildCategoryHeader('Operating Expenses & Settlement', SpriteIcons.receipt, const Color(0xFF0F172A)),
          if (!report.isConsolidated) ...[
            _buildLineItem(
              'Franchise Base Rent',
              -report.baseRentPaidToMainBoss,
              indent: true,
            ),
            _buildLineItem(
              'Franchise Sales Royalty (3.0%)',
              -report.salesRoyaltyPaidToMainBoss,
              indent: true,
            ),
          ],
          _buildLineItem(
            'Store Operating Expenses (Wages, Utilities, Supplies)',
            -report.operatingExpenses,
            indent: true,
          ),
          _buildTotalRow(
            'Net Operating Income',
            report.netOperatingIncome,
            badgeColor: const Color(0xFF475569),
          ),

          const SizedBox(height: 6),

          // 3. OTHER INFLOWS / BANKING
          _buildCategoryHeader('Other Inflows & Banking', SpriteIcons.accounting, const Color(0xFF0F172A)),
          _buildLineItem(
            'Other Inflows (Vendor Rebates, Platform Share)',
            report.otherIncome,
          ),
          _buildLineItem(
            'Banking & Payment Processing Fees',
            -report.otherExpenses,
          ),
          _buildTotalRow('Net Other Inflows', report.netOtherIncome),

          const SizedBox(height: 10),

          // 4. BOTTOM LINE: NET INCOME
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: report.netIncome >= 0
                  ? const Color(0xFFF0FDF4)
                  : const Color(0xFFFFF1F2),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(
                top: BorderSide(
                  color: report.netIncome >= 0
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFECDD3),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    AppSvgIcon.sprite(
                      report.netIncome >= 0
                          ? SpriteIcons.checkCircle
                          : SpriteIcons.warning,
                      size: 20,
                      color: report.netIncome >= 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFE11D48),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Net Income (Bottom Line)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          report.netIncome >= 0
                              ? 'Net Profit Retained'
                              : 'Net Operating Loss',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: report.netIncome >= 0
                                ? const Color(0xFF15803D)
                                : const Color(0xFFBE123C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: report.netIncome >= 0
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFDA4AF),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    report.netIncome < 0
                        ? '- \$ ${report.netIncome.abs().toStringAsFixed(2)}'
                        : '+ \$ ${report.netIncome.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: report.netIncome >= 0
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFE11D48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, String spriteIcon, Color accentColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          AppSvgIcon.sprite(spriteIcon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItem(
    String label,
    double amount, {
    bool indent = false,
    bool isPrimary = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: indent ? 40.0 : 20.0,
        right: 20.0,
        top: 8.0,
        bottom: 8.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.normal,
                color: isPrimary ? const Color(0xFF0F172A) : const Color(0xFF475569),
              ),
            ),
          ),
          Text(
            amount < 0
                ? '(\$ ${amount.abs().toStringAsFixed(2)})'
                : '\$ ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
              color: amount < 0
                  ? const Color(0xFF64748B)
                  : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount, {
    String? badge,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? const Color(0xFF0D9488))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: badgeColor ?? const Color(0xFF0D9488),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Text(
            amount < 0
                ? '(\$ ${amount.abs().toStringAsFixed(2)})'
                : '\$ ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
