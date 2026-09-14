import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app_config.dart';
import '../models/order_model.dart';
import '../models/store_settings_model.dart';
import '../services/printer_service.dart';
import '../services/receipt_file_service.dart';
import '../core/theme/asset_theme.dart';
import '../core/theme/sprite_icons.dart';
import 'app_logo_widget.dart';
import 'app_svg_icon.dart';

enum ReceiptMode {
  unpaidNoQr,
  unpaidQr,
  paid,
}

class ReceiptPreviewDialog extends StatefulWidget {
  final OrderModel order;
  final StoreSettingsModel settings;
  final Future<bool> Function()? onReprint;
  final ReceiptSaveResult? existingSaveResult;
  final VoidCallback? onCompletedReturnHome;
  final bool? initialIsPaid;
  final ReceiptMode? initialMode;

  const ReceiptPreviewDialog({
    super.key,
    required this.order,
    required this.settings,
    this.onReprint,
    this.existingSaveResult,
    this.onCompletedReturnHome,
    this.initialIsPaid,
    this.initialMode,
  });

  @override
  State<ReceiptPreviewDialog> createState() => _ReceiptPreviewDialogState();
}

class _ReceiptPreviewDialogState extends State<ReceiptPreviewDialog> {
  final ScrollController _scrollController = ScrollController();

  ReceiptSaveResult? _saveResult;
  bool _isPrintingPdf = false;
  late ReceiptMode _mode;

  bool get _isPaid => _mode == ReceiptMode.paid;
  bool get _showQr => _mode == ReceiptMode.unpaidQr;

  @override
  void initState() {
    super.initState();
    _saveResult = widget.existingSaveResult;
    if (widget.initialMode != null) {
      _mode = widget.initialMode!;
    } else if (widget.initialIsPaid == true ||
        (widget.initialIsPaid == null && widget.order.status == OrderStatus.completed)) {
      _mode = ReceiptMode.paid;
    } else {
      _mode = ReceiptMode.unpaidQr;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handlePdfPrint() async {
    if (_isPrintingPdf) return;
    setState(() => _isPrintingPdf = true);

    try {
      if (widget.onReprint != null && _isPaid) {
        await widget.onReprint!.call();
      } else {
        await PrinterService().printReceipt(
          order: widget.order,
          settings: widget.settings,
          isPaid: _isPaid,
          showQr: _showQr,
          isReprint: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingPdf = false);
    }

    // Prompt user & smoothly auto-close dialog back to POS screen
    if (mounted) {
      final docName = _isPaid
          ? 'Paid Receipt #${widget.order.receiptNo}'
          : (_showQr
              ? 'Bill (QR) #${widget.order.orderNumber ?? widget.order.receiptNo.split('-').last}'
              : 'Bill #${widget.order.orderNumber ?? widget.order.receiptNo.split('-').last}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.print_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Printing $docName...'),
            ],
          ),
          backgroundColor: const Color(0xFF0D9488),
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
        width: settings.isPaperSize80mm ? 345 : 300,
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
                        child: const AppSvgIcon.sprite(
                          SpriteIcons.receipt,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  // Mode Toggle Tabs: Bill (No QR) vs Bill (QR) vs Paid Receipt
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _mode = ReceiptMode.unpaidNoQr),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: _mode == ReceiptMode.unpaidNoQr
                                  ? const Color(0xFF0D9488)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'No QR',
                              style: TextStyle(
                                color: _mode == ReceiptMode.unpaidNoQr ? Colors.white : Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        InkWell(
                          onTap: () => setState(() => _mode = ReceiptMode.unpaidQr),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: _mode == ReceiptMode.unpaidQr
                                  ? const Color(0xFF0D9488)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Bill (QR)',
                              style: TextStyle(
                                color: _mode == ReceiptMode.unpaidQr ? Colors.white : Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        InkWell(
                          onTap: () => setState(() => _mode = ReceiptMode.paid),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: _mode == ReceiptMode.paid
                                  ? const Color(0xFF0D9488)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Paid',
                              style: TextStyle(
                                color: _mode == ReceiptMode.paid ? Colors.white : Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                      const SizedBox(height: 3),
                      _solidDivider(),

                      // 3. Metadata
                      if (!_isPaid) ...[
                        _rowMeta('Bill:', order.orderNumber ?? order.receiptNo.split('-').last),
                        _rowMeta('Date:', DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt)),
                        _rowMeta(
                          'Customer:',
                          (order.customerName != null &&
                                  order.customerName!.trim().isNotEmpty &&
                                  order.customerName!.trim().toLowerCase() != 'guest')
                              ? order.customerName!.trim()
                              : '...............',
                        ),
                      ] else ...[
                        _rowMeta('Order:', '${order.receiptNo} (Paid)'),
                        _rowMeta('Date:', DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt)),
                        _rowMeta(
                          'Customer:',
                          (order.customerName != null &&
                                  order.customerName!.trim().isNotEmpty &&
                                  order.customerName!.trim().toLowerCase() != 'guest')
                              ? order.customerName!.trim()
                              : '...............',
                        ),
                      ],

                      _solidDivider(),

                      // 4. Column Headers: NAME, QTY, UNIT PRICE, AMOUNT
                      const Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              'NAME',
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
                              'UNIT PRICE',
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
                              'AMOUNT',
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
                      _solidDivider(),

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

                      _solidDivider(),

                      // 6. Totals Breakdown
                      _rowTotal(
                        'SUBTOTAL:',
                        '$currency${order.subtotal.toStringAsFixed(2)}',
                        fontSize: 9.5,
                      ),
                      _rowTotal(
                        'TOTAL (USD):',
                        '$currency${order.totalAmount.toStringAsFixed(2)}',
                        isBold: true,
                        fontSize: 11.0,
                      ),
                      if (settings.showKhrDualCurrency)
                        _rowTotal(
                          'TOTAL (KHR):',
                          '${NumberFormat('#,###').format((order.totalAmount * settings.usdToKhrRate).round())} KHR',
                          isBold: true,
                          fontSize: 10.5,
                        ),

                      _solidDivider(),

                      // 7. Payment Info (Paid) OR KHQR Section (Not Paid)
                      if (_isPaid) ...[
                        const SizedBox(height: 1),
                        _rowTotal(
                          'PAYMENT METHOD:',
                          order.paymentMethod.displayName.toUpperCase(),
                          isBold: true,
                          fontSize: 9.5,
                        ),
                        const SizedBox(height: 2),
                        _solidDivider(),
                      ] else if (_showQr) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'Bakong & All Mobile Banking Apps',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: (settings.qrImagePath != null &&
                                    settings.qrImagePath!.trim().isNotEmpty &&
                                    File(settings.qrImagePath!).existsSync())
                                ? Image.file(
                                    File(settings.qrImagePath!),
                                    width: 135,
                                    height: 135,
                                    fit: BoxFit.contain,
                                  )
                                : QrImageView(
                                    data: (settings.qrPayloadTemplate.isNotEmpty &&
                                            !settings.qrPayloadTemplate.contains('pay.restaurant.com'))
                                        ? (settings.qrPayloadTemplate.contains('{order}')
                                            ? settings.qrPayloadTemplate.replaceAll(
                                                '{order}',
                                                order.orderNumber ?? order.receiptNo,
                                              )
                                            : (settings.qrPayloadTemplate.endsWith('=')
                                                ? '${settings.qrPayloadTemplate}${order.orderNumber ?? order.receiptNo}'
                                                : settings.qrPayloadTemplate))
                                        : 'KHQR:MERCHANT:${settings.storeName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase()}:INV#${order.orderNumber ?? order.receiptNo}:USD${order.totalAmount.toStringAsFixed(2)}:KHR${(order.totalAmount * settings.usdToKhrRate).round()}',
                                    version: QrVersions.auto,
                                    size: 115.0,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Scan with banking app or pay with Cash / Card',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8.0,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 3),
                        _solidDivider(),
                      ] else ...[
                        const SizedBox(height: 2),
                        const Text(
                          'UNPAID BILL / INVOICE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Please present this bill at cashier counter to pay',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8.0,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 3),
                        _solidDivider(),
                      ],

                      // 8. Footer (both modes)
                      const SizedBox(height: 2),
                      const Text(
                        '***THANK YOU FOR YOUR VISIT***',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        '***Please Come Again***',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
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
                      icon: const AppSvgIcon.sprite(
                        SpriteIcons.arrowLeft,
                        size: 14,
                        color: Color(0xFF64748B),
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
                          : const AppSvgIcon.sprite(
                              SpriteIcons.printer,
                              size: 15,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isPrintingPdf
                            ? 'Printing...'
                            : (_isPaid
                                ? 'Print Paid Receipt'
                                : (_showQr ? 'Print Bill (QR)' : 'Print Bill (No QR)')),
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

  Widget _solidDivider({double height = 7, double thickness = 0.8}) {
    return Container(
      height: height,
      alignment: Alignment.center,
      child: Container(
        height: thickness,
        color: Colors.black,
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
