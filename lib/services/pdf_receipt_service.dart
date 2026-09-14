import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/order_model.dart';
import '../models/store_settings_model.dart';
import 'printer_service.dart';

class PdfReceiptFileInfo {
  final String fileName;
  final String filePath;
  final int fileSizeBytes;
  final DateTime modifiedAt;
  final String receiptNo;

  const PdfReceiptFileInfo({
    required this.fileName,
    required this.filePath,
    required this.fileSizeBytes,
    required this.modifiedAt,
    required this.receiptNo,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    }
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class PdfReceiptSaveResult {
  final String appDocPath;
  final String? downloadsPath;
  bool get success =>
      appDocPath.isNotEmpty ||
      (downloadsPath != null && downloadsPath!.isNotEmpty);

  const PdfReceiptSaveResult({required this.appDocPath, this.downloadsPath});
}

class PdfReceiptService {
  static final PdfReceiptService _instance = PdfReceiptService._internal();
  factory PdfReceiptService() => _instance;
  PdfReceiptService._internal();

  /// Safely load logo image bytes from file or Flutter assets
  Future<Uint8List?> _loadLogoBytes(StoreSettingsModel settings) async {
    if (!settings.printLogoOnReceipt) return null;

    // 1. Explicit logo path in settings (Disk File or Asset)
    if (settings.logoPath != null && settings.logoPath!.trim().isNotEmpty) {
      final rawPath = settings.logoPath!.trim();

      // Check if disk file (normalize Windows/Unix slashes)
      try {
        final normalizedPath = rawPath.replaceAll('/', Platform.pathSeparator);
        final file = File(normalizedPath);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          if (bytes.isNotEmpty) return bytes;
        }
      } catch (_) {}

      try {
        final file = File(rawPath);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          if (bytes.isNotEmpty) return bytes;
        }
      } catch (_) {}

      // Check if Flutter asset
      try {
        final assetKey = rawPath.replaceAll(r'\', '/');
        final byteData = await rootBundle.load(assetKey);
        return byteData.buffer.asUint8List();
      } catch (_) {}
    }

    // 2. Primary fallback to official store logo (ca.png)
    try {
      final byteData = await rootBundle.load('assets/images/ca.png');
      return byteData.buffer.asUint8List();
    } catch (_) {}

    try {
      final caFile = File('assets/images/ca.png');
      if (caFile.existsSync()) {
        return caFile.readAsBytesSync();
      }
    } catch (_) {}

    // 3. Fallback to app_logo.png
    try {
      final byteData = await rootBundle.load('assets/app_logo.png');
      return byteData.buffer.asUint8List();
    } catch (_) {}

    return null;
  }

  /// Safely load Bank QR image bytes from file or Flutter assets
  Future<Uint8List?> _loadQrBytes(StoreSettingsModel settings) async {
    if (settings.qrImagePath != null &&
        settings.qrImagePath!.trim().isNotEmpty) {
      final rawPath = settings.qrImagePath!.trim();
      try {
        final file = File(rawPath);
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          if (bytes.isNotEmpty) return bytes;
        }
      } catch (_) {}

      try {
        final byteData = await rootBundle.load(rawPath);
        return byteData.buffer.asUint8List();
      } catch (_) {}
    }
    return null;
  }

  /// Construct bank payment QR data payload (strictly bank payment, never dummy store URL)
  String _buildPaymentQrData(StoreSettingsModel settings, OrderModel order) {
    final raw = settings.qrPayloadTemplate.trim();
    if (raw.isNotEmpty && !raw.contains('pay.restaurant.com')) {
      if (raw.contains('{order}')) {
        return raw.replaceAll('{order}', order.orderNumber ?? order.receiptNo);
      }
      if (raw.endsWith('=')) {
        return '$raw${order.orderNumber ?? order.receiptNo}';
      }
      return raw;
    }
    final storeClean = settings.storeName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    final amt = order.totalAmount.toStringAsFixed(2);
    final khrAmt = (order.totalAmount * settings.usdToKhrRate).round();
    return 'KHQR:MERCHANT:$storeClean:INV#${order.orderNumber ?? order.receiptNo}:USD$amt:KHR$khrAmt';
  }

  /// Generates high-quality PDF Receipt bytes for 80mm/58mm thermal roll
  Future<Uint8List> generateReceiptPdf({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isPaid = true,
    bool showQr = true,
    bool isReprint = false,
  }) async {
    final doc = pw.Document();

    final currency = settings.currencySymbol;
    final is80mm = settings.isPaperSize80mm;
    // Physical printable width for 80mm thermal head is 72mm (204.1 pt); 58mm thermal head is 48mm (136.1 pt)
    final printableWidth =
        is80mm ? (72.0 * PdfPageFormat.mm) : (48.0 * PdfPageFormat.mm);
    final baseFontSize = is80mm ? 8.0 : 7.0;

    final topMargin = settings.printerMarginTop * PdfPageFormat.mm;
    final bottomMargin = settings.printerMarginBottom * PdfPageFormat.mm;
    final leftMargin = settings.printerMarginLeft * PdfPageFormat.mm;
    final rightMargin = settings.printerMarginRight * PdfPageFormat.mm;

    final logoBytes = await _loadLogoBytes(settings);
    pw.MemoryImage? logoImage;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {}
    }

    final qrBytes = await _loadQrBytes(settings);
    pw.MemoryImage? qrImage;
    if (qrBytes != null && qrBytes.isNotEmpty) {
      try {
        qrImage = pw.MemoryImage(qrBytes);
      } catch (_) {}
    }

    final paymentQrData = _buildPaymentQrData(settings, order);

    final effectiveCustomer = (order.customerName != null &&
            order.customerName!.trim().isNotEmpty &&
            order.customerName!.trim().toLowerCase() != 'guest')
        ? order.customerName!.trim()
        : '...............';
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt);
    final billNo = order.orderNumber ?? order.receiptNo.split('-').last;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          printableWidth,
          double.infinity,
          marginLeft: leftMargin,
          marginRight: rightMargin,
          marginTop: topMargin,
          marginBottom: bottomMargin,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // 1. Store Logo at the Top
              if (logoImage != null) ...[
                pw.Center(
                  child: pw.Image(
                    logoImage,
                    width: is80mm ? 56 : 42,
                    height: is80mm ? 56 : 42,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(height: 3),
              ],

              // 2. Store Header & Subtitle
              pw.Text(
                settings.storeName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: is80mm ? 13 : 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (settings.storeAddress.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  settings.storeAddress.toUpperCase(),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: is80mm ? 8.5 : 7.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
              pw.SizedBox(height: 3),
              pw.Divider(thickness: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 2),

              if (isReprint) ...[
                pw.Center(
                  child: pw.Text(
                    '*** DUPLICATE REPRINT ***',
                    style: pw.TextStyle(
                      fontSize: baseFontSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 2),
              ],

              // 3. Order / Bill Metadata
              if (!isPaid) ...[
                _buildMetaRow('Bill:', billNo, fontSize: baseFontSize),
                _buildMetaRow('Date:', dateStr, fontSize: baseFontSize),
                _buildMetaRow('Customer:', effectiveCustomer, fontSize: baseFontSize),
              ] else ...[
                _buildMetaRow('Order:', '${order.receiptNo} (Paid)', fontSize: baseFontSize),
                _buildMetaRow('Date:', dateStr, fontSize: baseFontSize),
                _buildMetaRow('Customer:', effectiveCustomer, fontSize: baseFontSize),
              ],

              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 2),

              // 4. Items Table Header (NAME, QTY, UNIT PRICE, AMOUNT)
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text(
                      'NAME',
                      style: pw.TextStyle(
                        fontSize: baseFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.SizedBox(
                    width: is80mm ? 26 : 20,
                    child: pw.Text(
                      'QTY',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: baseFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'UNIT PRICE',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: baseFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text(
                      'AMOUNT',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        fontSize: baseFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 2),

              // 5. Line Items
              ...order.items.map((item) {
                final itemSubtotal = item.unitPrice * item.quantity;
                final discount = itemSubtotal - item.totalPrice;
                final hasDiscount = discount > 0.009;

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            flex: 5,
                            child: pw.Text(
                              item.productName,
                              style: pw.TextStyle(fontSize: baseFontSize),
                            ),
                          ),
                          pw.SizedBox(
                            width: is80mm ? 26 : 20,
                            child: pw.Text(
                              '${item.quantity}',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(fontSize: baseFontSize),
                            ),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              '$currency${item.unitPrice.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: baseFontSize),
                            ),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(
                              '$currency${item.totalPrice.toStringAsFixed(2)}',
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(fontSize: baseFontSize),
                            ),
                          ),
                        ],
                      ),
                      if (hasDiscount)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 2, top: 0.5),
                          child: pw.Text(
                            '+ Discount: -$currency${discount.toStringAsFixed(2)}',
                            style: pw.TextStyle(
                              fontSize: baseFontSize - 1,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ),
                      if (item.notes != null && item.notes!.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 2, top: 0.5),
                          child: pw.Text(
                            '+ Note: ${item.notes}',
                            style: pw.TextStyle(
                              fontSize: baseFontSize - 1,
                              fontStyle: pw.FontStyle.italic,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 2),

              // 6. Totals Breakdown
              _buildTwoCol(
                'SUBTOTAL:',
                '$currency${order.subtotal.toStringAsFixed(2)}',
                fontSize: baseFontSize,
              ),
              _buildTwoCol(
                'TOTAL (USD):',
                '$currency${order.totalAmount.toStringAsFixed(2)}',
                bold: true,
                fontSize: baseFontSize + 1.5,
              ),
              if (settings.showKhrDualCurrency)
                _buildTwoCol(
                  'TOTAL (KHR):',
                  '${NumberFormat('#,###').format((order.totalAmount * settings.usdToKhrRate).round())} KHR',
                  bold: true,
                  fontSize: baseFontSize + 1.5,
                ),

              pw.SizedBox(height: 2),
              pw.Divider(thickness: 0.8, color: PdfColors.black),

              // 7. Payment Info (Paid) OR KHQR Section (Not Paid)
              if (isPaid) ...[
                pw.SizedBox(height: 1),
                _buildTwoCol(
                  'PAYMENT METHOD:',
                  order.paymentMethod.displayName.toUpperCase(),
                  bold: true,
                  fontSize: baseFontSize,
                ),
                pw.SizedBox(height: 2),
                pw.Divider(thickness: 0.8, color: PdfColors.black),
              ] else if (showQr) ...[
                pw.SizedBox(height: 3),
                pw.Center(
                  child: pw.Text(
                    'Bakong & All Mobile Banking Apps',
                    style: pw.TextStyle(
                      fontSize: baseFontSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                if (qrImage != null)
                  pw.Center(
                    child: pw.Image(
                      qrImage,
                      width: is80mm ? 100 : 78,
                      height: is80mm ? 100 : 78,
                      fit: pw.BoxFit.contain,
                    ),
                  )
                else
                  pw.Center(
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: paymentQrData,
                      width: is80mm ? 100 : 78,
                      height: is80mm ? 100 : 78,
                    ),
                  ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'Scan with banking app or pay with Cash / Card',
                    style: pw.TextStyle(
                      fontSize: baseFontSize - 1.2,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Divider(thickness: 0.8, color: PdfColors.black),
              ] else ...[
                pw.SizedBox(height: 3),
                pw.Center(
                  child: pw.Text(
                    'UNPAID BILL / INVOICE',
                    style: pw.TextStyle(
                      fontSize: baseFontSize,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'Please present this bill at cashier counter to pay',
                    style: pw.TextStyle(
                      fontSize: baseFontSize - 1.2,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Divider(thickness: 0.8, color: PdfColors.black),
              ],

              // 8. Footer (both modes)
              pw.SizedBox(height: 3),
              pw.Text(
                '***THANK YOU FOR YOUR VISIT***',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: baseFontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 1),
              pw.Text(
                '***Please Come Again***',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: baseFontSize - 0.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  /// Generates high-quality Kitchen Ticket PDF for 80mm/58mm thermal roll
  Future<Uint8List> generateKitchenTicketPdf({
    required OrderModel order,
    required StoreSettingsModel settings,
  }) async {
    final doc = pw.Document();
    final is80mm = settings.isPaperSize80mm;
    final printableWidth =
        is80mm ? (72.0 * PdfPageFormat.mm) : (48.0 * PdfPageFormat.mm);
    final baseFontSize = is80mm ? 8.5 : 7.5;

    final topMargin = settings.printerMarginTop * PdfPageFormat.mm;
    final bottomMargin = settings.printerMarginBottom * PdfPageFormat.mm;
    final leftMargin = settings.printerMarginLeft * PdfPageFormat.mm;
    final rightMargin = settings.printerMarginRight * PdfPageFormat.mm;

    final orderNum = order.orderNumber ?? order.receiptNo.split('-').last;
    final tableNum = (order.tableNumber != null && order.tableNumber!.isNotEmpty)
        ? order.tableNumber!
        : (order.orderType == 'TAKEAWAY' ? 'TAKEAWAY' : 'COUNTER');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          printableWidth,
          double.infinity,
          marginLeft: leftMargin,
          marginRight: rightMargin,
          marginTop: topMargin,
          marginBottom: bottomMargin,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(
                child: pw.Text(
                  '*** KITCHEN ORDER ***',
                  style: pw.TextStyle(
                    fontSize: baseFontSize + 4,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1.2, color: PdfColors.black),
              pw.SizedBox(height: 2),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ORDER #:', style: pw.TextStyle(fontSize: baseFontSize + 2, fontWeight: pw.FontWeight.bold)),
                  pw.Text(orderNum, style: pw.TextStyle(fontSize: baseFontSize + 2, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TABLE:', style: pw.TextStyle(fontSize: baseFontSize + 2, fontWeight: pw.FontWeight.bold)),
                  pw.Text(tableNum, style: pw.TextStyle(fontSize: baseFontSize + 2, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Text('TYPE: ${order.orderType}', style: pw.TextStyle(fontSize: baseFontSize)),
              pw.Text(
                'TIME: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt)}',
                style: pw.TextStyle(fontSize: baseFontSize - 1),
              ),
              if (order.customerName != null &&
                  order.customerName!.trim().isNotEmpty &&
                  order.customerName!.trim().toLowerCase() != 'guest')
                pw.Text('CUSTOMER: ${order.customerName}', style: pw.TextStyle(fontSize: baseFontSize)),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1.0, color: PdfColors.black, borderStyle: pw.BorderStyle.dashed),
              pw.Center(
                child: pw.Text(
                  'ITEMS TO PREPARE',
                  style: pw.TextStyle(fontSize: baseFontSize + 1, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Divider(thickness: 1.0, color: PdfColors.black, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 4),

              // Items strictly without prices
              ...order.items.map((item) {
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${item.quantity}x ',
                            style: pw.TextStyle(
                              fontSize: baseFontSize + 3,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              item.productName.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: baseFontSize + 2,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.notes != null && item.notes!.trim().isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(left: 14, top: 1),
                          child: pw.Text(
                            '** NOTE: ${item.notes} **',
                            style: pw.TextStyle(
                              fontSize: baseFontSize,
                              fontStyle: pw.FontStyle.italic,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.2, color: PdfColors.black),
              pw.Center(
                child: pw.Text(
                  '--- KITCHEN COPY ---',
                  style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 6),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  /// Generates diagnostic test slip for verifying printer connection & cutter
  Future<Uint8List> generateTestReceiptPdf({
    required StoreSettingsModel settings,
    String? targetDeviceName,
  }) async {
    final doc = pw.Document();
    final is80mm = settings.isPaperSize80mm;
    final printableWidth =
        is80mm ? (72.0 * PdfPageFormat.mm) : (48.0 * PdfPageFormat.mm);
    final baseFontSize = is80mm ? 8.5 : 7.5;

    final topMargin = settings.printerMarginTop * PdfPageFormat.mm;
    final bottomMargin = settings.printerMarginBottom * PdfPageFormat.mm;
    final leftMargin = settings.printerMarginLeft * PdfPageFormat.mm;
    final rightMargin = settings.printerMarginRight * PdfPageFormat.mm;

    final logoBytes = await _loadLogoBytes(settings);
    pw.MemoryImage? logoImage;
    if (logoBytes != null && logoBytes.isNotEmpty) {
      try {
        logoImage = pw.MemoryImage(logoBytes);
      } catch (_) {}
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          printableWidth,
          double.infinity,
          marginLeft: leftMargin,
          marginRight: rightMargin,
          marginTop: topMargin,
          marginBottom: bottomMargin,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (logoImage != null) ...[
                pw.Center(
                  child: pw.Image(
                    logoImage,
                    width: is80mm ? 52 : 40,
                    height: is80mm ? 52 : 40,
                    fit: pw.BoxFit.contain,
                  ),
                ),
                pw.SizedBox(height: 4),
              ],
              pw.Center(
                child: pw.Text(
                  settings.storeName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: baseFontSize + 3,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'PRINTER VERIFICATION TEST',
                  style: pw.TextStyle(fontSize: baseFontSize + 1, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1.0, color: PdfColors.black),
              pw.SizedBox(height: 3),

              pw.Text('Terminal: CA H2 (GD215-H2)', style: pw.TextStyle(fontSize: baseFontSize)),
              pw.Text(
                'Tested Device: ${targetDeviceName ?? "Auto-Detected"}',
                style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Status: 100% Connected & Verified', style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold)),
              pw.Text('Paper Roll: ${is80mm ? "80mm Standard" : "58mm Compact"}', style: pw.TextStyle(fontSize: baseFontSize)),
              pw.Text('Auto-Cutter: Active', style: pw.TextStyle(fontSize: baseFontSize)),
              pw.Text(
                'Test Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: baseFontSize - 1),
              ),

              pw.SizedBox(height: 5),
              pw.Divider(thickness: 1.0, color: PdfColors.black, borderStyle: pw.BorderStyle.dashed),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: 'CA-H2-PRINTER-VERIFIED-${DateTime.now().millisecondsSinceEpoch}',
                  width: 50,
                  height: 50,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  '*** Hardware Test Complete ***',
                  style: pw.TextStyle(fontSize: baseFontSize, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 6),
            ],
          );
        },
      ),
    );

    return await doc.save();
  }

  /// Automatically persists PDF receipt to Downloads and App Documents folder
  Future<PdfReceiptSaveResult> saveReceiptPdf({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isReprint = false,
  }) async {
    final pdfBytes = await generateReceiptPdf(
      order: order,
      settings: settings,
      isReprint: isReprint,
    );

    final fileName = 'Receipt_${order.receiptNo}.pdf';
    final dateFolder = DateFormat('yyyy-MM-dd').format(order.createdAt);
    String appDocPath = '';
    String? downloadsPath;

    // 1. App Documents Directory
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final sep = Platform.isWindows ? '\\' : '/';
      final targetDir = Directory(
        '${appDir.path}${sep}POS_Receipts$sep$dateFolder',
      );
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final file = File('${targetDir.path}$sep$fileName');
      await file.writeAsBytes(pdfBytes, flush: true);
      appDocPath = file.path;
    } catch (_) {}

    // Public Downloads are intentionally not used on Android; receipts can
    // contain customer and payment information.
    if (Platform.isWindows) {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final targetDir = Directory(
            '${downloadsDir.path}\\POS_Receipts\\$dateFolder',
          );
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
          final file = File('${targetDir.path}\\$fileName');
          await file.writeAsBytes(pdfBytes, flush: true);
          downloadsPath = file.path;
        }
      } catch (_) {}
    }

    return PdfReceiptSaveResult(
      appDocPath: appDocPath,
      downloadsPath: downloadsPath,
    );
  }

  /// Triggers system print or layout dialog (routes via PrinterService / SumatraPDF for silent thermal printing if enabled)
  Future<bool> printReceiptPdf({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isPaid = true,
    bool isReprint = false,
  }) async {
    try {
      if (Platform.isWindows && settings.useSumatraPdf) {
        final success = await PrinterService().printReceipt(
          order: order,
          settings: settings,
          isPaid: isPaid,
          isReprint: isReprint,
        );
        if (success) return true;
      }

      final pdfBytes = await generateReceiptPdf(
        order: order,
        settings: settings,
        isPaid: isPaid,
        isReprint: isReprint,
      );

      final docName = isPaid
          ? 'Receipt_${order.receiptNo}.pdf'
          : 'Bill_${order.orderNumber ?? order.receiptNo.split('-').last}.pdf';

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: docName,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Open PDF directly in Windows default PDF viewer or Android viewer app
  Future<OpenResult> openPdf(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return OpenResult(
          type: ResultType.fileNotFound,
          message: 'PDF file not found at: $filePath',
        );
      }
      final absolutePath = file.absolute.path;
      if (Platform.isWindows) {
        final result = await Process.run('cmd', [
          '/c',
          'start',
          '',
          absolutePath,
        ], runInShell: true);
        if (result.exitCode == 0) {
          return OpenResult(type: ResultType.done, message: 'Opened');
        }
      }
      return await OpenFilex.open(absolutePath);
    } catch (e) {
      return await OpenFilex.open(filePath);
    }
  }

  /// Highlight and reveal file in Windows File Explorer
  Future<void> showInExplorer(String filePath) async {
    if (Platform.isWindows) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await Process.run('explorer.exe', [
            '/select,',
            file.absolute.path,
          ], runInShell: true);
        }
      } catch (_) {}
    }
  }

  /// Share PDF file via Android/Windows share sheet
  Future<ShareResult> sharePdf(String filePath, {String? subject}) async {
    return await SharePlus.instance.share(
      ShareParams(files: [XFile(filePath)], subject: subject ?? 'Receipt PDF'),
    );
  }

  /// List all PDF receipts from App Documents and Downloads folder
  Future<List<PdfReceiptFileInfo>> listAllPdfReceipts() async {
    final results = <PdfReceiptFileInfo>[];
    final seenPaths = <String>{};

    void scanDir(Directory dir) {
      if (!dir.existsSync()) return;
      for (var entity in dir.listSync(recursive: true)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          final normalized = entity.absolute.path;
          if (!seenPaths.contains(normalized)) {
            seenPaths.add(normalized);
            final stat = entity.statSync();
            final name = entity.path
                .split(Platform.isWindows ? '\\' : '/')
                .last;
            final receiptNo = name
                .replaceAll('Receipt_', '')
                .replaceAll('.pdf', '');
            results.add(
              PdfReceiptFileInfo(
                fileName: name,
                filePath: normalized,
                fileSizeBytes: stat.size,
                modifiedAt: stat.modified,
                receiptNo: receiptNo,
              ),
            );
          }
        }
      }
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final sep = Platform.isWindows ? '\\' : '/';
      scanDir(Directory('${appDir.path}${sep}POS_Receipts'));
    } catch (_) {}

    if (Platform.isWindows) {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          scanDir(Directory('${downloadsDir.path}\\POS_Receipts'));
        }
      } catch (_) {}
    } else if (Platform.isAndroid) {
      try {
        scanDir(Directory('/storage/emulated/0/Download/POS_Receipts'));
      } catch (_) {}
    }

    results.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return results;
  }

  pw.Widget _buildMetaRow(String label, String value, {double fontSize = 8.0}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$label ',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: fontSize)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTwoCol(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 8.0,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Text(
            value,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
