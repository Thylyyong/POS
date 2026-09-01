import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/order_model.dart';
import '../models/store_settings_model.dart';

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
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class PdfReceiptSaveResult {
  final String appDocPath;
  final String? downloadsPath;
  bool get success => appDocPath.isNotEmpty || (downloadsPath != null && downloadsPath!.isNotEmpty);

  const PdfReceiptSaveResult({
    required this.appDocPath,
    this.downloadsPath,
  });
}

class PdfReceiptService {
  static final PdfReceiptService _instance = PdfReceiptService._internal();
  factory PdfReceiptService() => _instance;
  PdfReceiptService._internal();

  /// Generates high-quality PDF Receipt bytes for 80mm thermal roll
  Future<Uint8List> generateReceiptPdf({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isReprint = false,
  }) async {
    final doc = pw.Document();

    final currency = settings.currencySymbol;
    final dateFormatted = DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt);
    final isDineIn = order.orderType == 'DINE_IN';
    const rollWidth = 226.0;

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          rollWidth,
          double.infinity,
          marginAll: 8.0,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Store Header
              pw.Text(
                settings.storeName.toUpperCase(),
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (settings.storeAddress.isNotEmpty)
                pw.Text(
                  settings.storeAddress,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              if (settings.storePhone.isNotEmpty)
                pw.Text(
                  'Tel: ${settings.storePhone}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              if (isReprint) ...[
                pw.Center(
                  child: pw.Text(
                    '*** DUPLICATE REPRINT ***',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
              ],

              // Order & Table Info
              _buildTwoCol('Receipt #:', order.receiptNo, bold: true),
              if (order.orderNumber != null)
                _buildTwoCol('Order #:', '#${order.orderNumber}', bold: true),
              _buildTwoCol('Date:', dateFormatted),
              _buildTwoCol(
                'Type:',
                isDineIn ? 'Dine-In (${order.tableNumber ?? "T01"})' : order.orderType,
              ),
              if (order.customerName != null && order.customerName!.isNotEmpty)
                _buildTwoCol('Customer:', order.customerName!),
              _buildTwoCol('Payment:', order.paymentMethod.displayName),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Items Table Header
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: pw.Text('ITEM', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('QTY', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('TOTAL', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5),

              // Line Items
              ...order.items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.productName, style: const pw.TextStyle(fontSize: 8)),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              pw.Text('* ${item.notes}', style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          '$currency${item.totalPrice.toStringAsFixed(2)}',
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

              // Totals
              _buildTwoCol('Subtotal:', '$currency${order.subtotal.toStringAsFixed(2)}'),
              if (order.discountAmount > 0)
                _buildTwoCol(
                  order.discountPercent > 0
                      ? 'Discount (${order.discountPercent.toStringAsFixed(0)}%):'
                      : 'Discount:',
                  '-$currency${order.discountAmount.toStringAsFixed(2)}',
                ),
              if (order.taxAmount > 0)
                _buildTwoCol(
                  'Tax/VAT (${order.taxRate.toStringAsFixed(0)}%):',
                  '$currency${order.taxAmount.toStringAsFixed(2)}',
                ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL DUE:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    '$currency${order.totalAmount.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),

              if (order.paymentMethod == PaymentMethod.cash) ...[
                pw.SizedBox(height: 2),
                _buildTwoCol('Cash Tendered:', '$currency${order.cashTendered.toStringAsFixed(2)}'),
                _buildTwoCol('Change Due:', '$currency${order.changeAmount.toStringAsFixed(2)}', bold: true),
              ],

              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: '${settings.qrPayloadTemplate}${order.receiptNo}',
                  width: 55,
                  height: 55,
                ),
              ),

              pw.SizedBox(height: 6),
              if (settings.footerNote.isNotEmpty)
                pw.Text(
                  settings.footerNote,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 7.5, fontStyle: pw.FontStyle.italic),
                ),
              pw.SizedBox(height: 2),
              pw.Text(
                '*** OmniPOS Dual-Screen ***',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.SizedBox(height: 10),
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
      final targetDir = Directory('${appDir.path}${sep}POS_Receipts$sep$dateFolder');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final file = File('${targetDir.path}$sep$fileName');
      await file.writeAsBytes(pdfBytes, flush: true);
      appDocPath = file.path;
    } catch (_) {}

    // 2. Windows Downloads Directory or Android Public Downloads Directory
    if (Platform.isWindows) {
      try {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          final targetDir = Directory('${downloadsDir.path}\\POS_Receipts\\$dateFolder');
          if (!await targetDir.exists()) {
            await targetDir.create(recursive: true);
          }
          final file = File('${targetDir.path}\\$fileName');
          await file.writeAsBytes(pdfBytes, flush: true);
          downloadsPath = file.path;
        }
      } catch (_) {}
    } else if (Platform.isAndroid) {
      try {
        final downloadDir = Directory('/storage/emulated/0/Download/POS_Receipts/$dateFolder');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsBytes(pdfBytes, flush: true);
        downloadsPath = file.path;
      } catch (_) {}
    }

    return PdfReceiptSaveResult(
      appDocPath: appDocPath,
      downloadsPath: downloadsPath,
    );
  }

  /// Triggers system print or layout dialog
  Future<bool> printReceiptPdf({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isReprint = false,
  }) async {
    try {
      final pdfBytes = await generateReceiptPdf(
        order: order,
        settings: settings,
        isReprint: isReprint,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Receipt_${order.receiptNo}.pdf',
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
        return OpenResult(type: ResultType.fileNotFound, message: 'PDF file not found at: $filePath');
      }
      final absolutePath = file.absolute.path;
      if (Platform.isWindows) {
        final result = await Process.run('cmd', ['/c', 'start', '', absolutePath], runInShell: true);
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
          await Process.run('explorer.exe', ['/select,', file.absolute.path], runInShell: true);
        }
      } catch (_) {}
    }
  }

  /// Share PDF file via Android/Windows share sheet
  Future<ShareResult> sharePdf(String filePath, {String? subject}) async {
    return await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: subject ?? 'Receipt PDF',
      ),
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
            final name = entity.path.split(Platform.isWindows ? '\\' : '/').last;
            final receiptNo = name.replaceAll('Receipt_', '').replaceAll('.pdf', '');
            results.add(PdfReceiptFileInfo(
              fileName: name,
              filePath: normalized,
              fileSizeBytes: stat.size,
              modifiedAt: stat.modified,
              receiptNo: receiptNo,
            ));
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

  pw.Widget _buildTwoCol(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
