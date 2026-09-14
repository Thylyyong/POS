import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/accounting_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/theme/asset_theme.dart';
import '../../core/theme/sprite_icons.dart';
import '../../models/accounting_model.dart';
import '../../services/excel_export_service.dart';
import '../../widgets/app_svg_icon.dart';
import 'widgets/log_expense_dialog.dart';
import 'widgets/profit_loss_table_card.dart';

class ProfitLossScreen extends StatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountingController>().loadReport(branchId: 'all');
    });
  }

  @override
  Widget build(BuildContext context) {
    final accounting = context.watch<AccountingController>();
    final auth = context.watch<AuthController>();
    final report = accounting.report;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Ribbon (Zero Odoo references)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const AppSvgIcon.sprite(
                      SpriteIcons.accounting,
                      size: 20,
                      color: Color(0xFF0D9488),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Profit & Loss',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Financial statements & branch settlement overview',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),

                  // Period Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppSvgIcon(
                          AssetTheme.clock,
                          size: 13,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          accounting.selectedPeriod,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  if (auth.isMainBoss) ...[
                    OutlinedButton.icon(
                      onPressed: accounting.isExporting
                          ? null
                          : () async {
                              final settings = context.read<SettingsController>().settings;
                              final path = await accounting.exportVisibleReports(settings);
                              if (path != null) {
                                await ExcelExportService().openExcelFile(path);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          AppSvgIcon(
                                            AssetTheme.success,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'P&L report exported & opened in Excel!',
                                            ),
                                          ),
                                        ],
                                      ),
                                      action: SnackBarAction(
                                        label: 'Show Folder',
                                        textColor: Colors.white,
                                        onPressed: () => ExcelExportService().showInExplorer(path),
                                      ),
                                      backgroundColor: const Color(0xFF0F766E),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: accounting.isExporting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const AppSvgIcon(
                              AssetTheme.files,
                              size: 16,
                              color: Color(0xFF475569),
                            ),
                      label: const Text('Export Excel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Add Expense Button (Brand Emerald/Teal)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => LogExpenseDialog.show(context),
                    icon: const AppSvgIcon(
                      AssetTheme.plus,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Log Expense',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area (Full Width Responsive)
            Expanded(
              child: accounting.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : accounting.error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AppSvgIcon(
                              AssetTheme.clearWarning,
                              size: 40,
                              color: Color(0xFFDC2626),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              accounting.error!,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                accounting.clearError();
                                accounting.loadReport(
                                  branchId: auth.isMainBoss
                                      ? 'all'
                                      : auth.currentBranchId,
                                  period: accounting.selectedPeriod,
                                );
                              },
                              icon: const AppSvgIcon.sprite(SpriteIcons.refresh, size: 16),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : report == null
                  ? const Center(child: Text('No accounting report available'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Executive KPI Summary Cards Row ────────────────
                          _buildExecutiveKpiCards(report),
                          const SizedBox(height: 18),

                          // ── Financial Performance Breakdown Visual Bar ─────
                          _buildPerformanceBreakdownBar(report),
                          const SizedBox(height: 20),

                          // ── Single Business Financial Statement ──────────
                          _buildFinancialStatementSection(
                            report: report,
                            context: context,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Executive Financial KPI Cards Row
  Widget _buildExecutiveKpiCards(ProfitLossReportModel report) {
    final revenue = report.grossSalesRevenue;
    final cogs = report.costOfSales;
    final grossProfit = report.grossProfit;
    final grossMarginPercent = revenue > 0
        ? ((grossProfit / revenue) * 100).toStringAsFixed(1)
        : '0.0';
    final expenses = report.totalDirectExpenses;
    final netIncome = report.netIncome;
    final isProfitable = netIncome >= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final cardCount = isWide ? 5 : 2;
        final spacing = 12.0;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            _buildKpiCard(
              title: 'Total Sales',
              value: '\$ ${revenue.toStringAsFixed(2)}',
              subtitle: 'Gross sales revenue',
              badge: 'Revenue',
              spriteIcon: SpriteIcons.trendingUp,
              color: const Color(0xFF0F172A),
              width: _calculateCardWidth(constraints.maxWidth, cardCount, spacing),
            ),
            _buildKpiCard(
              title: 'Cost of Goods',
              value: '\$ ${cogs.toStringAsFixed(2)}',
              subtitle: revenue > 0
                  ? '${((cogs / revenue) * 100).toStringAsFixed(1)}% of sales'
                  : 'Ingredient & goods costs',
              badge: 'Direct Cost',
              spriteIcon: SpriteIcons.products,
              color: const Color(0xFF0F172A),
              width: _calculateCardWidth(constraints.maxWidth, cardCount, spacing),
            ),
            _buildKpiCard(
              title: 'Gross Profit',
              value: '\$ ${grossProfit.toStringAsFixed(2)}',
              subtitle: '$grossMarginPercent% gross margin',
              badge: 'Margin',
              spriteIcon: SpriteIcons.accounting,
              color: const Color(0xFF0F172A),
              width: _calculateCardWidth(constraints.maxWidth, cardCount, spacing),
            ),
            _buildKpiCard(
              title: 'Total Expenses',
              value: '\$ ${expenses.toStringAsFixed(2)}',
              subtitle: 'Wages, rent & settlement',
              badge: 'Overhead',
              spriteIcon: SpriteIcons.receipt,
              color: const Color(0xFF0F172A),
              width: _calculateCardWidth(constraints.maxWidth, cardCount, spacing),
            ),
            _buildKpiCard(
              title: isProfitable ? 'Net Profit' : 'Net Loss',
              value: isProfitable
                  ? '+ \$ ${netIncome.toStringAsFixed(2)}'
                  : '- \$ ${netIncome.abs().toStringAsFixed(2)}',
              subtitle: isProfitable ? 'Net operating gain' : 'Net operating deficit',
              badge: isProfitable ? 'Profitable' : 'Deficit',
              spriteIcon: isProfitable ? SpriteIcons.checkCircle : SpriteIcons.warning,
              color: isProfitable ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
              width: _calculateCardWidth(constraints.maxWidth, cardCount, spacing),
              isHero: true,
            ),
          ],
        );
      },
    );
  }

  double _calculateCardWidth(double totalWidth, int count, double spacing) {
    return (totalWidth - (spacing * (count - 1))) / count;
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required String badge,
    required String spriteIcon,
    required Color color,
    required double width,
    bool isHero = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHero
              ? (color == const Color(0xFF16A34A)
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFFECACA))
              : const Color(0xFFE2E8F0),
          width: isHero ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isHero
                      ? color.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AppSvgIcon.sprite(
                  spriteIcon,
                  size: 16,
                  color: isHero ? color : const Color(0xFF475569),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isHero
                      ? color.withValues(alpha: 0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isHero ? color : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Clean Financial Performance Overview Card
  Widget _buildPerformanceBreakdownBar(ProfitLossReportModel report) {
    final revenue = report.grossSalesRevenue;
    final cogs = report.costOfSales;
    final expenses = report.totalDirectExpenses;
    final cogsPercent = revenue > 0
        ? ((cogs / revenue) * 100).clamp(0.0, 100.0)
        : 0.0;
    final grossMarginPercent = revenue > 0
        ? ((report.grossProfit / revenue) * 100).clamp(0.0, 100.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  AppSvgIcon.sprite(SpriteIcons.analytics, size: 18, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Text(
                    'Financial Summary Breakdown',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                'Based on \$ ${report.grossSalesRevenue.toStringAsFixed(2)} Revenue',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Proportional Sales to Margin Breakdown Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (cogsPercent > 0)
                    Expanded(
                      flex: cogsPercent.round().clamp(1, 100),
                      child: Container(color: const Color(0xFF64748B)),
                    ),
                  if (grossMarginPercent > 0)
                    Expanded(
                      flex: grossMarginPercent.round().clamp(1, 100),
                      child: Container(color: const Color(0xFF0D9488)),
                    ),
                  if (cogsPercent == 0 && grossMarginPercent == 0)
                    Expanded(child: Container(color: const Color(0xFFE2E8F0))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Metrics Pills
          Row(
            children: [
              _buildSummaryPill(
                'Cost of Goods: ${cogsPercent.toStringAsFixed(1)}%',
                const Color(0xFF64748B),
                'Direct product inventory cost',
              ),
              const SizedBox(width: 16),
              _buildSummaryPill(
                'Gross Margin: ${grossMarginPercent.toStringAsFixed(1)}%',
                const Color(0xFF0D9488),
                'Profit kept before operating expenses',
              ),
              const SizedBox(width: 16),
              _buildSummaryPill(
                'Total Overhead: \$ ${expenses.toStringAsFixed(2)}',
                const Color(0xFF475569),
                'Wages, rent & branch settlement',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill(String label, Color dotColor, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Single-business official financial statement card containing P&L table
  Widget _buildFinancialStatementSection({
    required ProfitLossReportModel report,
    required BuildContext context,
  }) {
    final storeName = context.select<SettingsController, String>(
      (c) => c.settings.storeName.isNotEmpty ? c.settings.storeName : 'Main Business',
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Business Statement Card Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const AppSvgIcon.sprite(
                        SpriteIcons.building,
                        size: 18,
                        color: Color(0xFF0D9488),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Text(
                          'Official Profit & Loss Statement • Business Ledger',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: report.netIncome >= 0
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFFE4E6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: report.netIncome >= 0
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFDA4AF),
                    ),
                  ),
                  child: Text(
                    report.netIncome >= 0
                        ? 'NET: + \$ ${report.netIncome.toStringAsFixed(2)}'
                        : 'NET: - \$ ${report.netIncome.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: report.netIncome >= 0
                          ? const Color(0xFF15803D)
                          : const Color(0xFFBE123C),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Body: Single Unified P&L Statement Table
          Padding(
            padding: const EdgeInsets.all(20),
            child: ProfitLossTableCard(report: report),
          ),
        ],
      ),
    );
  }
}
