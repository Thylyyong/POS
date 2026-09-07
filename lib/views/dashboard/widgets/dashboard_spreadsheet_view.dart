import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../controllers/dashboard_controller.dart';
import '../../../models/order_model.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_svg_icon.dart';

class DashboardSpreadsheetView extends StatefulWidget {
  final DashboardController dashCtrl;
  final String currency;

  const DashboardSpreadsheetView({
    super.key,
    required this.dashCtrl,
    required this.currency,
  });

  @override
  State<DashboardSpreadsheetView> createState() =>
      _DashboardSpreadsheetViewState();
}

class _DashboardSpreadsheetViewState extends State<DashboardSpreadsheetView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allOrders = widget.dashCtrl.recentOrders;
    final filtered = _searchQuery.isEmpty
        ? allOrders
        : allOrders.where((o) {
            final q = _searchQuery.toLowerCase();
            return o.receiptNo.toLowerCase().contains(q) ||
                (o.customerName?.toLowerCase().contains(q) ?? false) ||
                o.paymentMethod.displayName.toLowerCase().contains(q) ||
                o.orderType.toLowerCase().contains(q) ||
                (o.tableNumber?.toLowerCase().contains(q) ?? false);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
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
          children: [
            // Search Bar & Row Count
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'Filter transactions by receipt #, customer, table, payment...',
                          hintStyle: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Padding(
                            padding: EdgeInsets.all(10),
                            child: AppSvgIcon(
                              AssetTheme.search,
                              size: 18,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const AppSvgIcon(
                                    AssetTheme.close,
                                    size: 16,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Showing ${filtered.length} of ${allOrders.length} records',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Spreadsheet Table Data
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No orders matching search filter',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF8FAFC),
                          ),
                          columnSpacing: 24,
                          horizontalMargin: 20,
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Receipt #',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Date / Time',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Customer',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Order Type',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Table',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Payment',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Items',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Total',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                          rows: filtered.map((ord) {
                            final timeStr = DateFormat('yyyy-MM-dd HH:mm')
                                .format(ord.createdAt);
                            final isCash =
                                ord.paymentMethod == PaymentMethod.cash;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    ord.receiptNo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    ord.customerName ?? 'Walk-in',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    ord.orderType.replaceAll('_', ' '),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    ord.tableNumber ?? 'Takeaway',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCash
                                          ? const Color(0xFFECFDF5)
                                          : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      ord.paymentMethod.displayName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isCash
                                            ? const Color(0xFF059669)
                                            : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${ord.items.length} items',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${widget.currency}${ord.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
