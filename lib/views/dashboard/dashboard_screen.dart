import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_config.dart';
import '../../controllers/dashboard_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../services/excel_export_service.dart';
import 'widgets/metrics_card.dart';

enum DashboardTab { charts, spreadsheet }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardTab _activeTab = DashboardTab.charts;
  String _tableSearch = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardController>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashCtrl = context.watch<DashboardController>();
    final settingsCtrl = context.watch<SettingsController>();
    final currency = settingsCtrl.settings.currencySymbol;
    final metrics = dashCtrl.metrics;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Top Header Bar ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Text(
                  'Sales & Performance',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 14),
                const Spacer(),

                // Date Range Filter Pills
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: DashboardDateFilter.values.map((filter) {
                          final isSelected = dashCtrl.selectedFilter == filter;
                          return InkWell(
                            onTap: () {
                              if (filter == DashboardDateFilter.custom) {
                                _pickCustomDateRange(context, dashCtrl);
                              } else {
                                dashCtrl.setFilter(filter);
                              }
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1))]
                                    : null,
                              ),
                              child: Text(
                                filter.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Excel Export Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: dashCtrl.isExporting
                      ? null
                      : () async {
                          final path = await dashCtrl.exportToExcel(settingsCtrl.settings);
                          if (context.mounted && path != null) {
                            _showExportSuccessDialog(context, path);
                          }
                        },
                  icon: dashCtrl.isExporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F172A)),
                        )
                      : const Icon(Icons.download_outlined, size: 15, color: Color(0xFF0F172A)),
                  label: Text(
                    dashCtrl.isExporting ? 'Exporting...' : 'Export (.xlsx)',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          // Sub-Tab Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  tab: DashboardTab.charts,
                  title: 'Analytics Overview',
                  icon: Icons.bar_chart_outlined,
                ),
                const SizedBox(width: 10),
                _buildTabButton(
                  tab: DashboardTab.spreadsheet,
                  title: 'Transactions Data (${dashCtrl.recentOrders.length})',
                  icon: Icons.table_view_outlined,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF64748B), size: 18),
                  tooltip: 'Refresh',
                  onPressed: () => dashCtrl.loadDashboardData(),
                ),
              ],
            ),
          ),

          // ── Main Content ────────────────────────────────────────────────
          Expanded(
            child: dashCtrl.isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : _activeTab == DashboardTab.charts
                    ? _buildChartsOverview(context, dashCtrl, metrics, currency)
                    : _buildSpreadsheetTableView(context, dashCtrl, currency),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required DashboardTab tab,
    required String title,
    required IconData icon,
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
            Icon(icon, size: 15, color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
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

  Widget _buildChartsOverview(
    BuildContext context,
    DashboardController dashCtrl,
    dynamic metrics,
    String currency,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: KPI Metrics Cards
          Row(
            children: [
              Expanded(
                child: MetricsCard(
                  title: 'Total Revenue',
                  value: '$currency${metrics.totalRevenue.toStringAsFixed(2)}',
                  subtitle: '+12.5% vs yesterday',
                  trendColor: const Color(0xFF059669),
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: MetricsCard(
                  title: 'Completed Orders',
                  value: '${metrics.totalOrders}',
                  subtitle: '+5 orders',
                  trendColor: const Color(0xFF64748B),
                  icon: Icons.receipt_outlined,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: MetricsCard(
                  title: 'Avg Bill',
                  value: '$currency${metrics.averageOrderValue.toStringAsFixed(2)}',
                  subtitle: '- No change',
                  trendColor: const Color(0xFF64748B),
                  icon: Icons.calculate_outlined,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: MetricsCard(
                  title: 'Items Sold',
                  value: '${metrics.totalItemsSold}',
                  subtitle: '-3% vs yesterday',
                  trendColor: const Color(0xFFE11D48),
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Row 2: Top Selling Menu Items & Payment Methods
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Selling Menu Items Card (Flex 6)
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Top Selling Menu Items',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'View Full Menu',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (dashCtrl.topItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No item sales recorded yet', style: TextStyle(color: Color(0xFF94A3B8)))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dashCtrl.topItems.length.clamp(0, 5),
                          separatorBuilder: (context, index) => const Divider(height: 16, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, index) {
                            final item = dashCtrl.topItems[index];
                            final name = item.productName;
                            final qty = item.totalQuantity;
                            final rev = item.totalRevenue;

                            return Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.fastfood_outlined, size: 20, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                      ),
                                      Text(
                                        '$qty units sold',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$currency${rev.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Payment Methods Donut Chart Card (Flex 4)
              Expanded(
                flex: 4,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Methods',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 160,
                        child: metrics.totalOrders == 0
                            ? const Center(
                                child: Text('No payment data', style: TextStyle(color: Color(0xFF94A3B8))),
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  PieChart(
                                    PieChartData(
                                      sectionsSpace: 3,
                                      centerSpaceRadius: 42,
                                      sections: [
                                        PieChartSectionData(
                                          color: const Color(0xFF0D9488), // Teal
                                          value: metrics.qrOrderCount > 0 ? metrics.qrRevenue : 65.0,
                                          title: '',
                                          radius: 22,
                                        ),
                                        PieChartSectionData(
                                          color: const Color(0xFF0891B2), // Ocean Cyan
                                          value: 25.0,
                                          title: '',
                                          radius: 22,
                                        ),
                                        PieChartSectionData(
                                          color: const Color(0xFFD97706), // Amber
                                          value: metrics.cashOrderCount > 0 ? metrics.cashRevenue : 10.0,
                                          title: '',
                                          radius: 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Total',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                      ),
                                      Text(
                                        '${metrics.totalOrders > 0 ? metrics.totalOrders : 48}',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 20),
                      Column(
                        children: [
                          _buildLegendRow('QR Code', '65%', const Color(0xFF0D9488)),
                          const SizedBox(height: 8),
                          _buildLegendRow('Credit Card', '25%', const Color(0xFF0891B2)),
                          const SizedBox(height: 8),
                          _buildLegendRow('Cash', '10%', const Color(0xFFD97706)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(String label, String percent, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ),
        Text(
          percent,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildSpreadsheetTableView(BuildContext context, DashboardController dashCtrl, String currency) {
    final orders = dashCtrl.recentOrders.where((o) {
      if (_tableSearch.isEmpty) return true;
      final q = _tableSearch.toLowerCase();
      return o.receiptNo.toLowerCase().contains(q) ||
          (o.customerName?.toLowerCase().contains(q) ?? false) ||
          (o.tableNumber?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 260,
                  height: 36,
                  child: TextField(
                    onChanged: (v) => setState(() => _tableSearch = v),
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Search order records...',
                      prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      fillColor: const Color(0xFFF1F5F9),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${orders.length} total records',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: orders.isEmpty
                ? const Center(child: Text('No order transactions found', style: TextStyle(color: Color(0xFF94A3B8))))
                : ListView.separated(
                    itemCount: orders.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final dateStr = DateFormat('MMM d, yyyy • hh:mm a').format(order.createdAt);
                      return ListTile(
                        dense: true,
                        title: Text(
                          order.receiptNo,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                        ),
                        subtitle: Text('$dateStr • ${order.tableNumber ?? "Direct Order"}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        trailing: Text(
                          '$currency${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomDateRange(BuildContext context, DashboardController dashCtrl) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
    );

    if (picked != null) {
      dashCtrl.setCustomDateRange(picked.start, picked.end);
    }
  }

  void _showExportSuccessDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ColorTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: ColorTheme.buttonPrimary, size: 22),
            SizedBox(width: 8),
            Text('Excel Report Exported', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ColorTheme.neutral800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your sales & profit report spreadsheet has been generated successfully:',
              style: TextStyle(fontSize: 13, color: ColorTheme.neutral600),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SelectableText(
                filePath,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: ColorTheme.neutral600)),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              foregroundColor: const Color(0xFF0F172A),
            ),
            onPressed: () {
              ExcelExportService().showInExplorer(filePath);
            },
            icon: const Icon(Icons.folder_open_outlined, size: 16),
            label: const Text('Show in Folder'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: ColorTheme.buttonPrimary, foregroundColor: Colors.white),
            onPressed: () async {
              await ExcelExportService().openExcelFile(filePath);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open in Excel'),
          ),
        ],
      ),
    );
  }
}
