import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../core/theme/asset_theme.dart';
import '../../widgets/app_svg_icon.dart';
import 'widgets/dashboard_charts_view.dart';
import 'widgets/dashboard_header_bar.dart';
import 'widgets/dashboard_spreadsheet_view.dart';

enum DashboardTab { charts, spreadsheet }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardTab _activeTab = DashboardTab.charts;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      final branchId = auth.isMainBoss ? 'all' : auth.currentBranchId;
      context.read<DashboardController>().loadDashboardData(branchId: branchId);
    });
  }

  void _showExportSuccessDialog(BuildContext context, String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            AppSvgIcon(AssetTheme.success, color: Color(0xFF059669), size: 22),
            SizedBox(width: 8),
            Text('Export Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The sales & performance report has been saved to:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                path,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF334155)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashCtrl = context.watch<DashboardController>();
    final settingsCtrl = context.watch<SettingsController>();
    final currency = settingsCtrl.settings.currencySymbol;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // 1. Modular Header Bar with Date Range Filters & Branch Selector
          DashboardHeaderBar(
            onExportExcel: () async {
              final path = await dashCtrl.exportToExcel(settingsCtrl.settings);
              if (context.mounted && path != null) {
                _showExportSuccessDialog(context, path);
              }
            },
          ),

          // 2. Sub-Tab Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  tab: DashboardTab.charts,
                  title: 'Analytics Overview',
                  svgAsset: AssetTheme.report,
                ),
                const SizedBox(width: 10),
                _buildTabButton(
                  tab: DashboardTab.spreadsheet,
                  title: 'Transactions Data (${dashCtrl.recentOrders.length})',
                  svgAsset: AssetTheme.files,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF64748B), size: 22),
                  tooltip: 'Refresh',
                  onPressed: () => dashCtrl.loadDashboardData(),
                ),
              ],
            ),
          ),

          // 3. Main Content: Charts or Live Spreadsheet
          Expanded(
            child: dashCtrl.isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : _activeTab == DashboardTab.charts
                    ? DashboardChartsView(dashCtrl: dashCtrl, currency: currency)
                    : DashboardSpreadsheetView(dashCtrl: dashCtrl, currency: currency),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required DashboardTab tab,
    required String title,
    required String svgAsset,
  }) {
    final isSelected = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFE2E8F0) : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSvgIcon(svgAsset, size: 15, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
