import 'package:flutter/material.dart';

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

          // 1. INCOME SECTION
          _buildCategoryHeader('Income'),
          _buildLineItem('Gross Product Sales', report.grossSalesRevenue),
          _buildLineItem(
            'Cost of Sales (COGS)',
            -report.costOfSales,
            indent: true,
          ),
          _buildTotalRow('Gross Profit', report.grossProfit),

          const Divider(height: 1),

          // 2. EXPENSE SECTION
          _buildCategoryHeader('Expense'),
          if (!report.isConsolidated) ...[
            _buildLineItem(
              'Base Store Rent to Main Boss (Fixed Low Rent)',
              -report.baseRentPaidToMainBoss,
              indent: true,
            ),
            _buildLineItem(
              'Product Sales Royalty (3.0% on Gross Sales)',
              -report.salesRoyaltyPaidToMainBoss,
              indent: true,
            ),
          ],
          _buildLineItem(
            'Local Operating Expenses (Staff, Power, Supplies)',
            -report.operatingExpenses,
            indent: true,
          ),
          _buildTotalRow('Net Operating Income', report.netOperatingIncome),

          const Divider(height: 1),

          // 3. OTHER INCOME / EXPENSE
          _buildLineItem(
            'Other Income (Rebates, Delivery Share)',
            report.otherIncome,
          ),
          _buildLineItem(
            'Other Expense (Card Merchant & Banking Fees)',
            -report.otherExpenses,
          ),
          _buildTotalRow('Net Other Income', report.netOtherIncome),

          const Divider(thickness: 1.5),

          // 4. BOTTOM LINE: NET INCOME
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net Income',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '\$ ${report.netIncome.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: report.netIncome >= 0
                        ? const Color(0xFF059669)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildLineItem(String label, double amount, {bool indent = false}) {
    return Padding(
      padding: EdgeInsets.only(
        left: indent ? 36.0 : 20.0,
        right: 20.0,
        top: 7.0,
        bottom: 7.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
          ),
          Text(
            amount < 0
                ? '(\$ ${amount.abs().toStringAsFixed(2)})'
                : '\$ ${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: amount < 0
                  ? const Color(0xFF64748B)
                  : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: const Color(0xFFF1F5F9).withValues(alpha: 0.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            amount < 0
                ? '(\$ ${amount.abs().toStringAsFixed(2)})'
                : '\$ ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
