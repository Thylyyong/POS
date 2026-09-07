import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../controllers/dashboard_controller.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_svg_icon.dart';
import 'metrics_card.dart';

class DashboardChartsView extends StatelessWidget {
  final DashboardController dashCtrl;
  final String currency;

  const DashboardChartsView({
    super.key,
    required this.dashCtrl,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = dashCtrl.metrics;

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
                  subtitle: '+12.5% trend',
                  trendColor: const Color(0xFF059669),
                  svgAsset: AssetTheme.wallet,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: MetricsCard(
                  title: 'Completed Orders',
                  value: '${metrics.totalOrders}',
                  subtitle:
                      '${metrics.cashOrderCount} Cash • ${metrics.qrOrderCount} QR',
                  trendColor: const Color(0xFF64748B),
                  svgAsset: AssetTheme.files,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: MetricsCard(
                  title: 'Avg Bill',
                  value:
                      '$currency${metrics.averageOrderValue.toStringAsFixed(2)}',
                  subtitle: 'Per completed order',
                  trendColor: const Color(0xFF64748B),
                  svgAsset: AssetTheme.payment,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: MetricsCard(
                  title: 'Items Sold',
                  value: '${metrics.totalItemsSold}',
                  subtitle: 'Menu units',
                  trendColor: const Color(0xFF0284C7),
                  svgAsset: AssetTheme.cart,
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
                      const Text(
                        'Top Selling Menu Items',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (dashCtrl.topItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No item sales recorded for this period',
                              style: TextStyle(color: Color(0xFF94A3B8)),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dashCtrl.topItems.length.clamp(0, 6),
                          separatorBuilder: (context, index) => const Divider(
                            height: 16,
                            color: Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final item = dashCtrl.topItems[index];
                            final name = item.productName;
                            final qty = item.totalQuantity;
                            final rev = item.totalRevenue;

                            return Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: AppSvgIcon(
                                      AssetTheme.box,
                                      size: 19,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        '$qty units sold',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '$currency${rev.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
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
                      const Text(
                        'Payment Methods',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 180,
                        child: metrics.totalRevenue == 0
                            ? const Center(
                                child: Text(
                                  'No payment data available',
                                  style: TextStyle(color: Color(0xFF94A3B8)),
                                ),
                              )
                            : PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 46,
                                  sections: [
                                    if (metrics.cashRevenue > 0)
                                      PieChartSectionData(
                                        color: const Color(0xFF0D9488),
                                        value: metrics.cashRevenue,
                                        title:
                                            '${((metrics.cashRevenue / metrics.totalRevenue) * 100).toStringAsFixed(0)}%',
                                        radius: 40,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    if (metrics.qrRevenue > 0)
                                      PieChartSectionData(
                                        color: const Color(0xFF3B82F6),
                                        value: metrics.qrRevenue,
                                        title:
                                            '${((metrics.qrRevenue / metrics.totalRevenue) * 100).toStringAsFixed(0)}%',
                                        radius: 40,
                                        titleStyle: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      // Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem(
                            'Cash ($currency${metrics.cashRevenue.toStringAsFixed(0)})',
                            const Color(0xFF0D9488),
                          ),
                          const SizedBox(width: 16),
                          _buildLegendItem(
                            'QR / Card ($currency${metrics.qrRevenue.toStringAsFixed(0)})',
                            const Color(0xFF3B82F6),
                          ),
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
