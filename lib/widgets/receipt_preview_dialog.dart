import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_config.dart';
import '../models/order_model.dart';
import '../models/store_settings_model.dart';
import '../services/pdf_receipt_service.dart';
import '../services/receipt_file_service.dart';
import '../core/theme/asset_theme.dart';
import 'app_svg_icon.dart';

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
              AppSvgIcon(
                result.success ? AssetTheme.success : AssetTheme.clearWarning,
                color: Colors.white,
                size: 18,
              ),
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
          backgroundColor: result.success
              ? ColorTheme.buttonPrimary
              : ColorTheme.semanticRed,
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
              const Icon(Icons.print_outlined, color: Colors.white, size: 18),
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
    final dateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss')
        .format(order.createdAt);
    final saved = _saveResult?.success == true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: settings.isPaperSize80mm ? 390 : 330,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
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
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receipt Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (order.orderNumber != null)
                            Text(
                              'Order #${order.orderNumber}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const AppSvgIcon(
                      AssetTheme.close,
                      color: Colors.white70,
                      size: 18,
                    ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                color: ColorTheme.neutral100,
                child: Row(
                  children: [
                    const AppSvgIcon(
                      AssetTheme.success,
                      size: 14,
                      color: ColorTheme.primary400,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Saved to ${_saveResult!.downloadsPath != null ? "App & Downloads" : "App Docs"} • ${order.receiptNo}.md',
                        style: const TextStyle(
                          fontSize: 11,
                          color: ColorTheme.primary400,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Receipt paper body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Store Header
                      Text(
                        settings.storeName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.5,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Divider(
                        color: Colors.black,
                        thickness: 1.5,
                        height: 10,
                      ),
                      const SizedBox(height: 2),

                      // Order Metadata
                      _rowMeta('Order:', order.receiptNo),
                      _rowMeta('Date:', dateFormatted),
                      _rowMeta(
                        'Customer:',
                        (order.customerName != null &&
                                order.customerName!.trim().isNotEmpty &&
                                order.customerName!.trim().toLowerCase() !=
                                    'guest')
                            ? order.customerName!
                            : '...............',
                      ),
                      const SizedBox(height: 2),
                      const Divider(
                        color: Colors.black,
                        thickness: 1.5,
                        height: 10,
                      ),
                      const SizedBox(height: 2),

                      // Column Headers
                      const Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              'NAME',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 36,
                            child: Text(
                              'QTY',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'UNIT PRICE',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'AMOUNT',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Divider(
                        color: Colors.black,
                        thickness: 1.2,
                        height: 8,
                      ),
                      const SizedBox(height: 2),

                      // Items list
                      ...order.items.map((item) {
                        final itemSubtotal = item.unitPrice * item.quantity;
                        final discount = itemSubtotal - item.totalPrice;
                        final hasDiscount = discount > 0.009;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 36,
                                    child: Text(
                                      '${item.quantity}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '$currency${item.unitPrice.toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      '$currency${item.totalPrice.toStringAsFixed(2)}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (hasDiscount)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 2,
                                    top: 1,
                                  ),
                                  child: Text(
                                    '+ Discount: -$currency${discount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              if (item.notes != null && item.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 2,
                                    top: 1,
                                  ),
                                  child: Text(
                                    '+ Note: ${item.notes}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 2),
                      const Divider(
                        color: Colors.black,
                        thickness: 1.2,
                        height: 8,
                      ),
                      const SizedBox(height: 4),

                      // Totals
                      _rowTotal(
                        'SUBTOTAL:',
                        '$currency${order.subtotal.toStringAsFixed(2)}',
                      ),
                      _rowTotal(
                        'TOTAL (USD):',
                        '$currency${order.totalAmount.toStringAsFixed(2)}',
                        isBold: true,
                        fontSize: 14,
                      ),
                      if (settings.showKhrDualCurrency)
                        _rowTotal(
                          'TOTAL (KHR):',
                          '${NumberFormat('#,###').format((order.totalAmount * settings.usdToKhrRate).round())} KHR',
                          isBold: true,
                          fontSize: 14,
                        ),

                      const SizedBox(height: 4),
                      const Divider(
                        color: Colors.black,
                        thickness: 2.0,
                        height: 10,
                      ),
                      const SizedBox(height: 4),

                      // Payment Breakdown
                      _rowTotal(
                        'PAYMENT METHOD:',
                        order.paymentMethod.displayName.toUpperCase(),
                      ),
                      if (order.paymentMethod == PaymentMethod.cash) ...[
                        _rowTotal(
                          'CASH RECEIVED:',
                          '$currency${(order.cashTendered > 0 ? order.cashTendered : order.totalAmount).toStringAsFixed(2)}',
                        ),
                        _rowTotal(
                          'CHANGE RETURN:',
                          '$currency${order.changeAmount.toStringAsFixed(2)}',
                        ),
                      ],

                      const SizedBox(height: 4),
                      const Divider(
                        color: Colors.black,
                        thickness: 1.2,
                        height: 8,
                      ),
                      const SizedBox(height: 8),

                      // Footer
                      const Text(
                        '***THANK YOU FOR YOUR VISIT***',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '***Please Come Again***',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _closeDialog,
                          icon: const AppSvgIcon(
                            AssetTheme.chevronLeft,
                            size: 16,
                            color: Color(0xFF475569),
                          ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isPrintingPdf ? null : _handlePdfPrint,
                          icon: _isPrintingPdf
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.print_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                          label: Text(
                            _isPrintingPdf
                                ? 'Opening PDF...'
                                : 'Print PDF Receipt',
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
                        foregroundColor: saved
                            ? ColorTheme.primary400
                            : ColorTheme.neutral600,
                        backgroundColor: saved
                            ? ColorTheme.neutral100
                            : Colors.white,
                        side: BorderSide(
                          color: saved
                              ? ColorTheme.primary400
                              : ColorTheme.neutral300,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSaving ? null : _handleSaveToFile,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ColorTheme.buttonPrimary,
                              ),
                            )
                          : AppSvgIcon(
                              saved ? AssetTheme.box : AssetTheme.files,
                              size: 16,
                              color: saved
                                  ? ColorTheme.primary400
                                  : ColorTheme.neutral600,
                            ),
                      label: Text(
                        _isSaving
                            ? 'Saving...'
                            : saved
                            ? 'Receipt File Saved (.md)'
                            : 'Save Receipt (.md file)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _rowMeta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: Colors.black,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12.5, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowTotal(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 12.5,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: fontSize,
              color: Colors.black,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: fontSize,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
