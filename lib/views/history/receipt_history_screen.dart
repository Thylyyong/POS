import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../app_config.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/pos_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../database/order_dao.dart';
import '../../models/order_model.dart';
import '../../models/store_settings_model.dart';
import '../../services/pdf_receipt_service.dart';
import '../../widgets/receipt_preview_dialog.dart';
import '../../core/theme/asset_theme.dart';
import '../../widgets/app_svg_icon.dart';

enum HistoryTab { orders, folder }

class ReceiptHistoryScreen extends StatefulWidget {
  final VoidCallback? onSwitchToPos;

  const ReceiptHistoryScreen({super.key, this.onSwitchToPos});

  @override
  State<ReceiptHistoryScreen> createState() => _ReceiptHistoryScreenState();
}

class _ReceiptHistoryScreenState extends State<ReceiptHistoryScreen> {
  final OrderDao _orderDao = OrderDao();
  final PdfReceiptService _pdfService = PdfReceiptService();

  HistoryTab _activeTab = HistoryTab.orders;
  List<OrderModel> _orders = [];
  List<PdfReceiptFileInfo> _pdfFiles = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final orders = await _orderDao.getOrders(searchQuery: _searchQuery, limit: 100);
    final pdfs = await _pdfService.listAllPdfReceipts();
    setState(() {
      _orders = orders;
      _pdfFiles = pdfs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsCtrl = context.watch<SettingsController>();
    final posCtrl = context.read<PosController>();
    final settings = settingsCtrl.settings;
    final currency = settings.currencySymbol;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Row(
                  children: [
                    AppSvgIcon(AssetTheme.files, color: Color(0xFF0F172A), size: 24),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receipt Archive & PDF Folder',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'View receipts, open saved PDF files, reprint, or share',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),

                // Search Bar
                SizedBox(
                  width: 280,
                  height: 38,
                  child: TextField(
                    onChanged: (val) {
                      _searchQuery = val;
                      _loadData();
                    },
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search Receipt #, Table, Guest...',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(10),
                        child: AppSvgIcon(AssetTheme.search, size: 18, color: Color(0xFF64748B)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                      fillColor: const Color(0xFFF1F5F9),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Refresh Button
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF64748B), size: 22),
                  tooltip: 'Refresh',
                  onPressed: _loadData,
                ),
              ],
            ),
          ),

          // Sub-Tab Navigation Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  tab: HistoryTab.orders,
                  title: 'Order Transactions (${_orders.length})',
                  svgAsset: AssetTheme.files,
                ),
                const SizedBox(width: 10),
                _buildTabButton(
                  tab: HistoryTab.folder,
                  title: 'Saved PDF Folder (${_pdfFiles.length} files)',
                  svgAsset: AssetTheme.box,
                ),
                const Spacer(),
                const Text(
                  'Saved to: /Download/POS_Receipts/ & App Storage',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          // Content Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
                : _activeTab == HistoryTab.orders
                    ? _buildOrdersListView(context, settings, currency, posCtrl)
                    : _buildPdfFolderView(context, settings),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required HistoryTab tab,
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
          color: isSelected ? ColorTheme.cardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? ColorTheme.neutral300 : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSvgIcon(svgAsset, size: 16, color: isSelected ? ColorTheme.primary400 : ColorTheme.neutral600),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? ColorTheme.primary400 : ColorTheme.neutral600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersListView(
    BuildContext context,
    StoreSettingsModel settings,
    String currency,
    PosController posCtrl,
  ) {
    if (_orders.isEmpty) {
      return const Center(
        child: Text('No orders found matching criteria', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _orders[index];
        final isCash = order.paymentMethod == PaymentMethod.cash;
        final isPending = order.status == OrderStatus.pending;
        final dateStr = DateFormat('MMM d, yyyy • hh:mm a').format(order.createdAt);

        final isOpenableInPos = isPending && widget.onSwitchToPos != null;

        return InkWell(
          onTap: isOpenableInPos ? () => _openPendingOrderInPos(order, posCtrl, context) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                // Receipt Number & Order ID
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              order.receiptNo,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (order.orderNumber != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: ColorTheme.neutral100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: ColorTheme.neutral300),
                              ),
                              child: Text(
                                '#${order.orderNumber}',
                                style: const TextStyle(color: ColorTheme.primary400, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(dateStr, style: const TextStyle(color: ColorTheme.neutral600, fontSize: 11.5)),
                    ],
                  ),
                ),

                // Table & Customer Info
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.tableNumber ?? (order.orderType == 'TAKEAWAY' ? 'Takeaway' : 'Table T01'),
                        style: const TextStyle(color: ColorTheme.neutral800, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      if (order.customerName != null && order.customerName!.isNotEmpty)
                        Text(
                          'Guest: ${order.customerName}',
                          style: const TextStyle(color: ColorTheme.neutral600, fontSize: 12),
                        ),
                    ],
                  ),
                ),

                // Payment Method Badge
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending
                            ? ColorTheme.statusOrangeBg
                            : isCash
                                ? ColorTheme.neutral100
                                : ColorTheme.primary50.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isPending
                              ? ColorTheme.statusOrange
                              : isCash
                                  ? ColorTheme.neutral300
                                  : ColorTheme.primary500,
                        ),
                      ),
                      child: Text(
                        isPending ? 'PENDING' : order.paymentMethod.displayName,
                        style: TextStyle(
                          color: isPending
                              ? ColorTheme.statusOrange
                              : isCash
                                  ? ColorTheme.primary400
                                  : ColorTheme.primary500,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                // Total Amount
                Expanded(
                  flex: 2,
                  child: Text(
                    '$currency${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: ColorTheme.primary400,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Action Buttons
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorTheme.neutral100,
                        foregroundColor: ColorTheme.primary400,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _openReceiptPreview(context, order, settings, posCtrl),
                      icon: const AppSvgIcon(AssetTheme.eyeOpen, size: 16, color: ColorTheme.primary400),
                      label: const Text('View Receipt'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const AppSvgIcon(AssetTheme.files, color: ColorTheme.semanticRed, size: 20),
                      tooltip: 'Print / Open PDF Receipt',
                      onPressed: () => _pdfService.printReceiptPdf(order: order, settings: settings),
                    ),
                    IconButton(
                      icon: const AppSvgIcon(AssetTheme.files, color: ColorTheme.primary400, size: 20),
                      tooltip: 'Reprint Thermal Receipt',
                      onPressed: () async {
                        final success = await posCtrl.reprintReceipt(order: order, settings: settings);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Receipt ${order.receiptNo} sent to printer!' : 'Reprint command queued.'),
                              backgroundColor: ColorTheme.buttonPrimary,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPdfFolderView(BuildContext context, StoreSettingsModel settings) {
    if (_pdfFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppSvgIcon(AssetTheme.files, size: 54, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'No PDF receipts generated yet',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Completing orders automatically saves PDF files to /Download/POS_Receipts/',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ],
        ),
      );
    }

    final filtered = _pdfFiles.where((p) {
      if (_searchQuery.isEmpty) return true;
      return p.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.receiptNo.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final pdf = filtered[index];
        final modStr = DateFormat('MMM d, yyyy • hh:mm a').format(pdf.modifiedAt);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
            ],
          ),
          child: Row(
            children: [
              // PDF File Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppConfig.accentRose.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(child: AppSvgIcon(AssetTheme.files, color: AppConfig.accentRose, size: 24)),
              ),
              const SizedBox(width: 14),

              // File Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pdf.fileName,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Size: ${pdf.formattedSize} • Created: $modStr',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    Text(
                      pdf.filePath,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorTheme.buttonPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final res = await _pdfService.openPdf(pdf.filePath);
                      if (res.type != ResultType.done && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Cannot open PDF: ${res.message}'),
                            action: SnackBarAction(
                              label: 'Show Folder',
                              onPressed: () => _pdfService.showInExplorer(pdf.filePath),
                            ),
                          ),
                        );
                      }
                    },
                    icon: const AppSvgIcon(AssetTheme.refer, size: 16, color: Colors.white),
                    label: const Text('Open PDF'),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const AppSvgIcon(AssetTheme.box, color: Color(0xFF64748B), size: 20),
                    tooltip: 'Show in File Explorer',
                    onPressed: () => _pdfService.showInExplorer(pdf.filePath),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const AppSvgIcon(AssetTheme.share, color: AppConfig.accentCyan, size: 20),
                    tooltip: 'Share / Send PDF',
                    onPressed: () => _pdfService.sharePdf(pdf.filePath, subject: 'Receipt ${pdf.receiptNo}'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPendingOrderInPos(
    OrderModel order,
    PosController posCtrl,
    BuildContext context,
  ) {
    final cart = context.read<CartController>();
    posCtrl.loadPendingOrderIntoCart(order, cart);
    cart.setTableInfo(
      tableId: order.tableId,
      tableNumber: order.tableNumber,
      customerName: order.customerName,
      orderType: order.orderType,
    );
    widget.onSwitchToPos?.call();
  }

  void _openReceiptPreview(
    BuildContext context,
    OrderModel order,
    StoreSettingsModel settings,
    PosController posCtrl,
  ) {
    showDialog(
      context: context,
      builder: (_) => ReceiptPreviewDialog(
        order: order,
        settings: settings,
        onReprint: () => posCtrl.reprintReceipt(order: order, settings: settings),
      ),
    );
  }
}
