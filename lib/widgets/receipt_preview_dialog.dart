import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../app_config.dart';
import '../models/order_model.dart';
import '../models/store_settings_model.dart';
import '../services/pdf_receipt_service.dart';
import '../services/receipt_file_service.dart';

class ReceiptPreviewDialog extends StatefulWidget {
  final OrderModel order;
  final StoreSettingsModel settings;
  final Future<bool> Function()? onReprint;
  final ReceiptSaveResult? existingSaveResult;
  final VoidCallback? onCompletedReturnHome;

  const ReceiptPreviewDialog({
    super.key,
    required this.order,
    required this.settings,
    this.onReprint,
    this.existingSaveResult,
    this.onCompletedReturnHome,
  });

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  final _receiptFileService = ReceiptFileService();
  final _pdfReceiptService = PdfReceiptService();

  ReceiptSaveResult? _saveResult;
  bool _isSaving = false;
  bool _isPrintingPdf = false;

  @override
  void initState() {
    super.initState();
    _saveResult = widget.existingSaveResult;
  }

  Future<void> _handleSaveToFile() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final result = await _receiptFileService.saveReceiptMarkdown(
        order: widget.order,
        settings: widget.settings,
      );
      setState(() => _saveResult = result);
      if (!mounted) return;
      final parts = <String>[];
      if (result.appDocPath.isNotEmpty) parts.add('App Documents');
      if (result.downloadsPath != null) parts.add('Downloads/POS_Receipts');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(result.success ? Icons.check_circle : Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.success
                      ? 'Saved to: ${parts.join(" & ")}\n${widget.order.receiptNo}.md'
                      : 'Save failed - check storage permissions.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          backgroundColor: result.success ? ColorTheme.buttonPrimary : ColorTheme.semanticRed,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handlePdfPrint() async {
    if (_isPrintingPdf) return;
    setState(() => _isPrintingPdf = true);

    // Call hardware reprint if provided
    widget.onReprint?.call();

    // Trigger PDF printing dialog
    _pdfReceiptService.printReceiptPdf(
      order: widget.order,
      settings: widget.settings,
    );

    // Prompt user & smoothly auto-close dialog back to POS screen
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.print, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Printing Receipt #${widget.order.receiptNo}...'),
            ],
          ),
          backgroundColor: ColorTheme.buttonPrimary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      widget.onCompletedReturnHome?.call();
    }
  }

  void _closeDialog() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    widget.onCompletedReturnHome?.call();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final settings = widget.settings;
    final currency = settings.currencySymbol;
    final dateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt);
    final saved = _saveResult?.success == true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 390,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A), // Slate-900
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receipt Preview',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (order.orderNumber != null)
                            Text(
                              'Order #${order.orderNumber}',
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _closeDialog,
                  ),
                ],
              ),
            ),

            // Saved-file banner
            if (saved)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: ColorTheme.neutral100,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: ColorTheme.primary400),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Saved to ${_saveResult!.downloadsPath != null ? "App & Downloads" : "App Docs"} • ${order.receiptNo}.md',
                        style: const TextStyle(fontSize: 11, color: ColorTheme.primary400, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Receipt paper body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                child: DefaultTextStyle(
                  style: const TextStyle(fontFamily: 'Courier', color: Color(0xFF1E293B), fontSize: 13, height: 1.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        settings.storeName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5, color: Color(0xFF0F172A)),
                      ),
                      if (settings.storeAddress.isNotEmpty)
                        Text(settings.storeAddress, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      if (settings.storePhone.isNotEmpty)
                        Text('Tel: ${settings.storePhone}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      const Text('================================', textAlign: TextAlign.center, maxLines: 1),
                      const SizedBox(height: 4),
                      _rcptRow('Receipt No:', order.receiptNo, bold: true),
                      if (order.orderNumber != null)
                        _rcptRow('Order No:', '#${order.orderNumber}', bold: true),
                      if (order.tableNumber != null && order.tableNumber!.isNotEmpty)
                        _rcptRow('Table / Spot:', order.tableNumber!, bold: true),
                      if (order.customerName != null && order.customerName!.isNotEmpty)
                        _rcptRow('Customer:', order.customerName!),
                      _rcptRow('Date/Time:', dateFormatted),
                      _rcptRow('Payment:', order.paymentMethod.displayName),
                      const SizedBox(height: 4),
                      const Text('--------------------------------', textAlign: TextAlign.center, maxLines: 1),
                      const Row(
                        children: [
                          Expanded(flex: 5, child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                          Expanded(flex: 3, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const Text('--------------------------------', textAlign: TextAlign.center, maxLines: 1),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      if (item.notes != null && item.notes!.isNotEmpty)
                                        Text('* ${item.notes}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Expanded(flex: 2, child: Text('${item.quantity}', textAlign: TextAlign.center)),
                                Expanded(flex: 3, child: Text('$currency${item.totalPrice.toStringAsFixed(2)}', textAlign: TextAlign.right)),
                              ],
                            ),
                          )),
                      const SizedBox(height: 4),
                      const Text('================================', textAlign: TextAlign.center, maxLines: 1),
                      _rcptRow('Subtotal:', '$currency${order.subtotal.toStringAsFixed(2)}'),
                      if (order.discountAmount > 0)
                        _rcptRow(
                          order.discountPercent > 0 ? 'Discount (${order.discountPercent.toStringAsFixed(0)}%):' : 'Discount:',
                          '-$currency${order.discountAmount.toStringAsFixed(2)}',
                        ),
                      if (order.taxAmount > 0)
                        _rcptRow('Tax/VAT (${order.taxRate.toStringAsFixed(0)}%):', '$currency${order.taxAmount.toStringAsFixed(2)}'),
                      const SizedBox(height: 4),
                      const Text('--------------------------------', textAlign: TextAlign.center, maxLines: 1),
                      _rcptRow('TOTAL DUE:', '$currency${order.totalAmount.toStringAsFixed(2)}', bold: true, fontSize: 15),
                      if (order.paymentMethod == PaymentMethod.cash) ...[
                        const SizedBox(height: 4),
                        _rcptRow('Cash Tendered:', '$currency${order.cashTendered.toStringAsFixed(2)}'),
                        _rcptRow('Change Due:', '$currency${order.changeAmount.toStringAsFixed(2)}', bold: true),
                      ],
                      const SizedBox(height: 10),
                      Center(
                        child: QrImageView(
                          data: '${settings.qrPayloadTemplate}${order.receiptNo}',
                          version: QrVersions.auto,
                          size: 70.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (settings.footerNote.isNotEmpty)
                        Text(settings.footerNote,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      const Text('*** OmniPOS System ***', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Close button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF475569),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _closeDialog,
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('Back to POS'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // PDF Print button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D9488),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: _isPrintingPdf ? null : _handlePdfPrint,
                          icon: _isPrintingPdf
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.print, size: 18),
                          label: Text(
                            _isPrintingPdf ? 'Opening PDF...' : 'Print PDF Receipt',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Save Receipt markdown file button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: saved ? ColorTheme.primary400 : ColorTheme.neutral600,
                        backgroundColor: saved ? ColorTheme.neutral100 : Colors.white,
                        side: BorderSide(color: saved ? ColorTheme.primary400 : ColorTheme.neutral300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSaving ? null : _handleSaveToFile,
                      icon: _isSaving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: ColorTheme.buttonPrimary))
                          : Icon(saved ? Icons.folder_open : Icons.save_alt, size: 16),
                      label: Text(
                        _isSaving ? 'Saving...' : saved ? 'Receipt File Saved (.md) ✓' : 'Save Receipt (.md file)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rcptRow(String label, String value, {bool bold = false, double fontSize = 13}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: fontSize,
      color: const Color(0xFF0F172A),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
