import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/product_dao.dart';
import '../models/stock_audit_log_model.dart';

/// Comprehensive modal dialog for viewing internal audit logs and waste tracking.
class StockAuditLogsDialog extends StatefulWidget {
  final String? initialProductId;
  final String? initialProductName;

  const StockAuditLogsDialog({
    super.key,
    this.initialProductId,
    this.initialProductName,
  });

  static Future<void> show(
    BuildContext context, {
    String? productId,
    String? productName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StockAuditLogsDialog(
        initialProductId: productId,
        initialProductName: productName,
      ),
    );
  }

  @override
  State<StockAuditLogsDialog> createState() => _StockAuditLogsDialogState();
}

class _StockAuditLogsDialogState extends State<StockAuditLogsDialog>
    with SingleTickerProviderStateMixin {
  final ProductDao _productDao = ProductDao();
  late TabController _tabController;

  List<StockAuditLog> _allLogs = [];
  List<StockAuditLog> _wasteLogs = [];
  bool _isLoading = true;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final all = await _productDao.getStockAuditLogs(
      productId: widget.initialProductId,
      limit: 150,
    );
    final waste = await _productDao.getStockAuditLogs(
      productId: widget.initialProductId,
      wasteOnly: true,
      limit: 150,
    );

    if (mounted) {
      setState(() {
        _allLogs = all;
        _wasteLogs = waste;
        _isLoading = false;
      });
    }
  }

  List<StockAuditLog> _filterList(List<StockAuditLog> list) {
    if (_searchFilter.trim().isEmpty) return list;
    final q = _searchFilter.toLowerCase().trim();
    return list.where((log) {
      return log.productName.toLowerCase().contains(q) ||
          log.userName.toLowerCase().contains(q) ||
          log.reasonDisplayName.toLowerCase().contains(q) ||
          (log.notes?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAll = _filterList(_allLogs);
    final filteredWaste = _filterList(_wasteLogs);
    final totalWasteUnits = _wasteLogs.fold<int>(
      0,
      (sum, l) => sum + l.changeQty.abs(),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.history_edu_rounded,
                      color: Color(0xFF0F172A),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.initialProductName != null
                              ? 'Audit & Waste History: ${widget.initialProductName}'
                              : 'Inventory Audit & Waste Tracking Log',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Full accountability trail: Who adjusted stock, when, and reason code',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ── Filter Bar & Tabs ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  // Tab selector
                  SizedBox(
                    width: 320,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF0D9488),
                      unselectedLabelColor: const Color(0xFF64748B),
                      indicatorColor: const Color(0xFF0D9488),
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      tabs: [
                        Tab(text: 'All Changes (${_allLogs.length})'),
                        Tab(text: 'Waste & Loss ($totalWasteUnits units)'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Search box
                  SizedBox(
                    width: 220,
                    height: 36,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchFilter = val),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Filter logs...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                        contentPadding: EdgeInsets.zero,
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body / List View ─────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0D9488)),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLogListView(filteredAll),
                        _buildLogListView(filteredWaste),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogListView(List<StockAuditLog> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'No audit records found.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final log = logs[index];
        final isPositive = log.changeQty > 0;
        final isZero = log.changeQty == 0;
        final changeColor = isZero
            ? const Color(0xFF64748B)
            : (isPositive ? const Color(0xFF0D9488) : const Color(0xFFDC2626));

        final (reasonBg, reasonText) = _getReasonBadgeColors(log.reasonCode);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              // Change quantity pill
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: changeColor.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: Text(
                  isZero
                      ? '0'
                      : (isPositive ? '+${log.changeQty}' : '${log.changeQty}'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: changeColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Product, Reason & Stock Progression
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          log.productName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: reasonBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log.reasonDisplayName,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: reasonText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Count: ${log.previousStock} → ${log.newStock} on hand',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (log.notes != null && log.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Note: ${log.notes}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF334155),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Staff / User Accountability & Timestamp
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          log.userName,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            log.userRole.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dateFormat.format(log.createdAt),
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  (Color, Color) _getReasonBadgeColors(String code) {
    switch (code.toLowerCase()) {
      case 'vendor_delivery':
        return (const Color(0xFFCCFBF1), const Color(0xFF0F766E));
      case 'recount':
        return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
      case 'damaged':
        return (const Color(0xFFFEE2E2), const Color(0xFFDC2626));
      case 'expired':
        return (const Color(0xFFFFEDD5), const Color(0xFFEA580C));
      case 'waste':
        return (const Color(0xFFFFE4E6), const Color(0xFFE11D48));
      case 'sale_deduction':
        return (const Color(0xFFF1F5F9), const Color(0xFF475569));
      default:
        return (const Color(0xFFF1F5F9), const Color(0xFF334155));
    }
  }
}
