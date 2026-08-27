import 'dart:io';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
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
  final ExcelExportService _excelService = ExcelExportService();
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
          // 1. Top Bar with Filter, Tabs & Excel Export Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Date Range Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: DashboardDateFilter.values.map((filter) {
                      final isSelected = dashCtrl.selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter.displayName),
                          selected: isSelected,
                          selectedColor: AppConfig.accentGreen.withValues(alpha: 0.18),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? AppConfig.accentGreenDark : const Color(0xFF475569),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppConfig.accentGreen : const Color(0xFFCBD5E1),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              if (filter == DashboardDateFilter.custom) {
                                _pickCustomDateRange(context, dashCtrl);
                              } else {
                                dashCtrl.setFilter(filter);
                              }
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Excel Export Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
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
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.file_download, size: 18),
                  label: Text(
                    dashCtrl.isExporting ? 'Exporting .xlsx...' : 'Export Excel (.xlsx)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Sub-Tab Switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  tab: DashboardTab.charts,
                  title: '📊 Analytics & Visual Charts',
                  icon: Icons.pie_chart_outline,
                ),
                const SizedBox(width: 12),
                _buildTabButton(
                  tab: DashboardTab.spreadsheet,
                  title: '📑 Live Excel Spreadsheet Table (${dashCtrl.recentOrders.length} records)',
                  icon: Icons.table_chart_outlined,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppConfig.accentGreen, size: 20),
                  tooltip: 'Refresh Dashboard',
                  onPressed: () => dashCtrl.loadDashboardData(),
                ),
              ],
            ),
          ),

          // 2. Main Body Content
          Expanded(
            child: dashCtrl.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppConfig.accentGreen))
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppConfig.accentGreen : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppConfig.accentGreenDark : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppConfig.accentGreenDark : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: KPI Metrics Cards
          Row(
            children: [
              Expanded(
                child: MetricsCard(
                  title: 'GROSS REVENUE',
                  value: '$currency${metrics.totalRevenue.toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  accentColor: AppConfig.accentGreen,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricsCard(
                  title: 'EST. GROSS PROFIT',
                  value: '$currency${metrics.grossProfit.toStringAsFixed(2)}',
                  icon: Icons.trending_up,
                  accentColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricsCard(
                  title: 'COMPLETED ORDERS',
                  value: '${metrics.totalOrders}',
                  icon: Icons.receipt_long,
                  accentColor: AppConfig.accentCyan,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: MetricsCard(
                  title: 'AVERAGE ORDER VALUE',
                  value: '$currency${metrics.averageOrderValue.toStringAsFixed(2)}',
                  icon: Icons.shopping_basket,
                  accentColor: AppConfig.accentAmber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Row 2: Charts & Top Items
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment Distribution Pie Chart Card
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
                        'Payment Method Breakdown',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: metrics.totalOrders == 0
                            ? const Center(
                                child: Text('No payment data in this period', style: TextStyle(color: Color(0xFF94A3B8))),
                              )
                            : PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 40,
                                  sections: [
                                    if (metrics.cashOrderCount > 0)
                                      PieChartSectionData(
                                        color: AppConfig.accentGreen,
                                        value: metrics.cashRevenue,
                                        title: 'Cash',
                                        radius: 45,
                                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    if (metrics.qrOrderCount > 0)
                                      PieChartSectionData(
                                        color: AppConfig.accentCyan,
                                        value: metrics.qrRevenue,
                                        title: 'QR',
                                        radius: 45,
                                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildLegend('Cash Payment', '$currency${metrics.cashRevenue.toStringAsFixed(2)}', AppConfig.accentGreen),
                          _buildLegend('QR Payment', '$currency${metrics.qrRevenue.toStringAsFixed(2)}', AppConfig.accentCyan),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Top Selling Menu Items
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
                      const Text(
                        'Top Selling Menu Items',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 16),
                      if (dashCtrl.topItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text('No item sales in this period', style: TextStyle(color: Color(0xFF94A3B8))),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dashCtrl.topItems.length,
                          separatorBuilder: (_, _) => const Divider(height: 12, color: Color(0xFFF1F5F9)),
                          itemBuilder: (context, i) {
                            final item = dashCtrl.topItems[i];
                            return Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: i < 3 ? AppConfig.accentAmber.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: i < 3 ? const Color(0xFFB45309) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.productName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A), fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '${item.totalQuantity} sold',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  '$currency${item.totalRevenue.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppConfig.accentGreenDark, fontSize: 14),
                                ),
                              ],
                            );
                          },
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

  Widget _buildSpreadsheetTableView(
    BuildContext context,
    DashboardController dashCtrl,
    String currency,
  ) {
    final orders = dashCtrl.recentOrders.where((o) {
      if (_tableSearch.isEmpty) return true;
      final q = _tableSearch.toLowerCase();
      return o.receiptNo.toLowerCase().contains(q) ||
          (o.orderNumber?.contains(q) ?? false) ||
          (o.customerName?.toLowerCase().contains(q) ?? false) ||
          (o.tableNumber?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Column(
      children: [
        // Table Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              SizedBox(
                width: 320,
                height: 40,
                child: TextField(
                  onChanged: (v) => setState(() => _tableSearch = v),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Filter spreadsheet rows...',
                    prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    fillColor: const Color(0xFFF1F5F9),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Showing ${orders.length} of ${dashCtrl.recentOrders.length} spreadsheet records',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),

        // Spreadsheet Data Table
        Expanded(
          child: orders.isEmpty
              ? const Center(child: Text('No orders found in this period', style: TextStyle(color: Color(0xFF94A3B8))))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        columnSpacing: 20,
                        headingTextStyle: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 12),
                        dataTextStyle: const TextStyle(color: Color(0xFF334155), fontSize: 12),
                        columns: const [
                          DataColumn(label: Text('RECEIPT #')),
                          DataColumn(label: Text('ORDER #')),
                          DataColumn(label: Text('DATE/TIME')),
                          DataColumn(label: Text('TYPE')),
                          DataColumn(label: Text('TABLE / SPOT')),
                          DataColumn(label: Text('CUSTOMER')),
                          DataColumn(label: Text('ITEMS')),
                          DataColumn(label: Text('SUBTOTAL')),
                          DataColumn(label: Text('DISCOUNT')),
                          DataColumn(label: Text('TAX')),
                          DataColumn(label: Text('TOTAL DUE')),
                          DataColumn(label: Text('PAYMENT')),
                          DataColumn(label: Text('STATUS')),
                        ],
                        rows: orders.map((o) {
                          final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(o.createdAt);
                          final itemsQty = o.items.fold(0, (sum, i) => sum + i.quantity);
                          return DataRow(cells: [
                            DataCell(Text(o.receiptNo, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                            DataCell(Text(o.orderNumber != null ? '#${o.orderNumber}' : '-')),
                            DataCell(Text(dateStr)),
                            DataCell(Text(o.orderType)),
                            DataCell(Text(o.tableNumber ?? 'N/A')),
                            DataCell(Text(o.customerName ?? 'Guest')),
                            DataCell(Text('$itemsQty items')),
                            DataCell(Text('$currency${o.subtotal.toStringAsFixed(2)}')),
                            DataCell(Text(o.discountAmount > 0 ? '-$currency${o.discountAmount.toStringAsFixed(2)}' : '-')),
                            DataCell(Text(o.taxAmount > 0 ? '$currency${o.taxAmount.toStringAsFixed(2)}' : '-')),
                            DataCell(Text('$currency${o.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppConfig.accentGreenDark))),
                            DataCell(Text(o.paymentMethod.displayName)),
                            DataCell(Text(o.status.displayName)),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLegend(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
      ],
    );
  }

  void _showExportSuccessDialog(BuildContext context, String filePath) {
    final fileName = filePath.split(Platform.isWindows ? '\\' : '/').last;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppConfig.accentGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle, color: AppConfig.accentGreenDark, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Excel Report Exported!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Multi-sheet .xlsx workbook generated',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // File Location Container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description, color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Saved to: $filePath',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final res = await _excelService.openExcelFile(filePath);
                        if (res.type != ResultType.done && ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Cannot open Excel file: ${res.message}')),
                          );
                        }
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open in Excel App', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _excelService.shareExcelFile(filePath),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share File'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomDateRange(BuildContext context, DashboardController ctrl) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: ctrl.customStartDate ?? DateTime.now().subtract(const Duration(days: 7)),
        end: ctrl.customEndDate ?? DateTime.now(),
      ),
    );
    if (picked != null) {
      ctrl.setCustomDateRange(picked.start, picked.end);
    }
  }
}
