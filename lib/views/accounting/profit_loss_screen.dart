import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/accounting_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/theme/asset_theme.dart';
import '../../widgets/app_svg_icon.dart';
import 'widgets/hybrid_settlement_card.dart';
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
      final auth = context.read<AuthController>();
      final initialBranch = auth.isMainBoss ? 'all' : auth.currentBranchId;
      context.read<AccountingController>().loadReport(branchId: initialBranch);
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
            // Odoo Top Navigation Ribbon
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  const AppSvgIcon(
                    AssetTheme.setting,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Profit and Loss',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Period Chip
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
                  const SizedBox(width: 8),

                  // Odoo Ribbon Action Buttons
                  _buildOdooRibbonButton('Comparison', AssetTheme.similar),
                  const SizedBox(width: 6),
                  _buildOdooRibbonButton(
                    'Posted Entries',
                    AssetTheme.checked,
                  ),
                  const SizedBox(width: 6),
                  _buildOdooRibbonButton(
                    'Report: Profit and Loss (US)',
                    AssetTheme.report,
                  ),
                  const SizedBox(width: 6),
                  _buildOdooRibbonButton('Budget', AssetTheme.target),
                  const SizedBox(width: 6),
                  _buildOdooRibbonButton(
                    'In \$',
                    AssetTheme.payment,
                  ),

                  const Spacer(),

                  if (auth.isMainBoss)
                    OutlinedButton.icon(
                      onPressed: accounting.isExporting
                          ? null
                          : () async {
                              final path = await accounting
                                  .exportVisibleReports(
                                    context.read<SettingsController>().settings,
                                  );
                              if (context.mounted && path != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'P&L Excel report exported: $path',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: accounting.isExporting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const AppSvgIcon(AssetTheme.files, size: 16, color: Color(0xFF475569)),
                      label: const Text('Export Excel'),
                    ),
                  const SizedBox(width: 8),

                  // Add Expense Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF714B67), // Odoo Purple
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => LogExpenseDialog.show(context),
                    icon: const AppSvgIcon(AssetTheme.plus, size: 16, color: Colors.white),
                    label: const Text(
                      'Log Expense',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
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
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : report == null
                  ? const Center(child: Text('No accounting report available'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                auth.isMainBoss
                                    ? 'Executive view: Store A, Store B and consolidated results'
                                    : 'Branch view: ${report.branchName}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...accounting.visibleReports.map(
                                (visibleReport) => Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        visibleReport.branchName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      HybridSettlementCard(
                                        report: visibleReport,
                                        auth: auth,
                                      ),
                                      const SizedBox(height: 12),
                                      ProfitLossTableCard(
                                        report: visibleReport,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOdooRibbonButton(String label, String svgAsset) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSvgIcon(svgAsset, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
