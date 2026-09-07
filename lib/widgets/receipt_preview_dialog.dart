import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_config.dart';
import '../models/order_model.dart';
import '../models/store_settings_model.dart';
import '../services/pdf_receipt_service.dart';
import '../services/receipt_file_service.dart';
import '../core/theme/asset_theme.dart';
import 'app_logo_widget.dart';
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
  final _pdfReceiptService = PdfReceiptService();
  final ScrollController _scrollController = ScrollController();

  ReceiptSaveResult? _saveResult;
  bool _isPrintingPdf = false;

  @override
  void initState() {
    super.initState();
    _saveResult = widget.existingSaveResult;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    final saved = _saveResult?.success == true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: settings.isPaperSize80mm ? 330 : 285,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A), // Slate-900
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(
                          Icons.receipt_long_outlined,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receipt Preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          if (order.orderNumber != null)
                            Text(
                              'Order #${order.orderNumber}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 9.5,
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
                      size: 14,
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
                  horizontal: 12,
                  vertical: 3,
                ),
                color: ColorTheme.neutral100,
                child: Row(
                  children: [
                    const AppSvgIcon(
                      AssetTheme.success,
                      size: 11,
                      color: ColorTheme.primary400,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Saved to ${_saveResult!.downloadsPath != null ? "App & Downloads" : "App Docs"} • ${order.receiptNo}.md',
                        style: const TextStyle(
                          fontSize: 9.5,
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
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9.5,
                    height: 1.2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Store Logo at the Top
                      Center(
                        child: AppLogoWidget(
                          logoPath: settings.logoPath,
                          size: 68,
                          borderRadius: 6,
                          fallbackSvg: AssetTheme.store,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 2. Store Header & Subtitle
                      Text(
                        settings.storeName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.0,
                          letterSpacing: 0.4,
                          color: Colors.black,
                        ),
                      ),
                      if (settings.storeAddress.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          settings.storeAddress.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      _dashedDivider(),

                      // 3. Order Metadata (Order #, Order Type, Date, Cashier)
                      _rowMeta('Order:', '#${order.orderNumber ?? order.receiptNo}'),
                      _rowMeta(
                        'Order Type:',
                        order.orderType == 'TAKEAWAY'
                            ? 'Takeaway'
                            : (order.tableNumber != null && order.tableNumber!.isNotEmpty
                                ? 'Dine-In (${order.tableNumber})'
                                : 'Dine-In'),
                      ),
                      _rowMeta('Date:', DateFormat('dd/MM/yyyy, hh:mm:ss a').format(order.createdAt)),
                      _rowMeta('Cashier:', 'System Admin'),
                      if (order.customerName != null &&
                          order.customerName!.trim().isNotEmpty &&
                          order.customerName!.trim().toLowerCase() != 'guest')
                        _rowMeta('Customer:', order.customerName!),

                      _dashedDivider(),

                      // 4. Column Headers: ITEM, QTY, PRICE, TOTAL
                      const Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              'ITEM',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 9.5,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 26,
                            child: Text(
                              'QTY',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 9.5,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'PRICE',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 9.5,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'TOTAL',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 9.5,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _dashedDivider(),

                      // 5. Line Items
                      ...order.items.map((item) {
                        final itemSubtotal = item.unitPrice * item.quantity;
                        final discount = itemSubtotal - item.totalPrice;
                        final hasDiscount = discount > 0.009;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.0),
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
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 26,
                                    child: Text(
                                      '${item.quantity}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 9.5,
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
                                        fontSize: 9.5,
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
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (hasDiscount)
                                Padding(
                                  padding: const EdgeInsets.only(left: 2, top: 0.5),
                                  child: Text(
                                    '+ Discount: -$currency${discount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              if (item.notes != null && item.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 2, top: 0.5),
                                  child: Text(
                                    '+ Note: ${item.notes}',
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),

                      _dashedDivider(),

                      // 6. Totals Breakdown
                      _rowTotal(
                        'Subtotal:',
                        '$currency${order.subtotal.toStringAsFixed(2)}',
                        fontSize: 9.5,
                      ),
                      _rowTotal(
                        'Total (\$):',
                        '$currency${order.totalAmount.toStringAsFixed(2)}',
                        isBold: true,
                        fontSize: 11.0,
                      ),
                      if (settings.showKhrDualCurrency)
                        _rowTotal(
                          'Total (KHR):',
                          'KHR ${NumberFormat('#,###').format((order.totalAmount * settings.usdToKhrRate).round())}',
                          isBold: true,
                          fontSize: 10.5,
                        ),

                      if (order.paymentMethod == PaymentMethod.cash) ...[
                        const SizedBox(height: 1),
                        _rowTotal(
                          'Payment Method:',
                          order.paymentMethod.displayName.toUpperCase(),
                          fontSize: 9.0,
                        ),
                        _rowTotal(
                          'Cash Received:',
                          '$currency${(order.cashTendered > 0 ? order.cashTendered : order.totalAmount).toStringAsFixed(2)}',
                          fontSize: 9.0,
                        ),
                        _rowTotal(
                          'Change Return:',
                          '$currency${order.changeAmount.toStringAsFixed(2)}',
                          fontSize: 9.0,
                        ),
                      ],

                      _dashedDivider(),

                      // 7. KHQR Header, QR Code & Caption
                      const Text(
                        'SCAN TO PAY WITH KHQR',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Bakong & All Mobile Banking Apps',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.0,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 3),

                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: (settings.qrImagePath != null &&
                                  settings.qrImagePath!.trim().isNotEmpty &&
                                  File(settings.qrImagePath!).existsSync())
                              ? Image.file(
                                  File(settings.qrImagePath!),
                                  width: 118,
                                  height: 118,
                                  fit: BoxFit.contain,
                                )
                              : QrImageView(
                                  data: settings.qrPayloadTemplate.isNotEmpty
                                      ? '${settings.qrPayloadTemplate}${order.receiptNo}'
                                      : 'REC:${order.receiptNo}',
                                  version: QrVersions.auto,
                                  size: 88.0,
                                ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Scan with banking app or pay with Cash / Card',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8.0,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 2),

                      _dashedDivider(),

                      // 8. Footer (under the QR code)
                      const Text(
                        '*** Thank you for your visit ***',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Please come again',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.0,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  // Back to POS button
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _closeDialog,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 12,
                      ),
                      label: const Text(
                        'Back to POS',
                        style: TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // PDF Print button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isPrintingPdf ? null : _handlePdfPrint,
                      icon: _isPrintingPdf
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.print_outlined,
                              size: 15,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isPrintingPdf
                            ? 'Opening PDF...'
                            : 'Print PDF Receipt',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
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

  Widget _dashedDivider({double height = 6, double dashWidth = 3.5, double dashSpace = 2.0}) {
    return SizedBox(
      height: height,
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final count = (width / (dashWidth + dashSpace)).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(count, (_) {
                return SizedBox(
                  width: dashWidth,
                  height: 1.0,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black87),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _rowMeta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 9.5,
              color: Colors.black,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 9.5, color: Colors.black),
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
    double fontSize = 9.5,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
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
