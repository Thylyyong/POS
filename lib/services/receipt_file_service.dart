import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/order_model.dart';
import '../models/store_settings_model.dart';

/// Result of a receipt save operation.
class ReceiptSaveResult {
  /// Path inside the app's Documents directory (always written).
  final String appDocPath;

  /// Path inside the public Downloads folder (written when permission allows).
  /// Null if the write failed or was skipped.
  final String? downloadsPath;

  /// Whether the app-docs path was saved successfully.
  bool get success => appDocPath.isNotEmpty;

  const ReceiptSaveResult({required this.appDocPath, this.downloadsPath});
}

/// Service that persists each completed order as a Markdown receipt file.
///
/// Saves to two locations:
///  1. `<AppDocuments>/receipts/YYYY-MM-DD/REC-YYYYMMDD-XXXX.md`  (always)
///  2. `/storage/emulated/0/Download/POS_Receipts/YYYY-MM-DD/REC-*.md` (best-effort)
class ReceiptFileService {
  static final ReceiptFileService _instance = ReceiptFileService._internal();
  factory ReceiptFileService() => _instance;
  ReceiptFileService._internal();

  static const _receiptSubDir = 'receipts';
  // ── Public API ─────────────────────────────────────────────────────────────

  /// Saves [order] + [settings] as a `.md` file in both locations.
  Future<ReceiptSaveResult> saveReceiptMarkdown({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isReprint = false,
  }) async {
    final markdown = _buildMarkdown(
      order: order,
      settings: settings,
      isReprint: isReprint,
    );
    final fileName = '${order.receiptNo}.md';
    final dateFolder = DateFormat('yyyy-MM-dd').format(order.createdAt);

    // 1. App Documents directory (private, always available, no permission needed)
    final appDocPath = await _writeToAppDocs(
      markdown: markdown,
      dateFolder: dateFolder,
      fileName: fileName,
    );

    return ReceiptSaveResult(appDocPath: appDocPath);
  }

  /// Returns all saved receipt files for a given [date] from app Documents.
  Future<List<File>> listReceiptFiles(DateTime date) async {
    try {
      final dateFolder = DateFormat('yyyy-MM-dd').format(date);
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docsDir.path}/$_receiptSubDir/$dateFolder');
      if (!await dir.exists()) return [];
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
    } catch (_) {
      return [];
    }
  }

  /// Reads and returns the Markdown content of a receipt file by receipt number.
  Future<String?> readReceiptFile(String receiptNo, DateTime date) async {
    try {
      final dateFolder = DateFormat('yyyy-MM-dd').format(date);
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File(
        '${docsDir.path}/$_receiptSubDir/$dateFolder/$receiptNo.md',
      );
      if (await file.exists()) return await file.readAsString();
    } catch (_) {}
    return null;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<String> _writeToAppDocs({
    required String markdown,
    required String dateFolder,
    required String fileName,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docsDir.path}/$_receiptSubDir/$dateFolder');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(markdown, flush: true);
      return file.path;
    } catch (_) {
      return '';
    }
  }

  // ── Markdown Builder ───────────────────────────────────────────────────────

  String _buildMarkdown({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isReprint = false,
  }) {
    final curr = settings.currencySymbol;
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt);
    final buf = StringBuffer();

    // Header
    buf.writeln('# \u{1F9FE} ${settings.storeName.toUpperCase()}');
    buf.writeln();
    if (settings.storeAddress.isNotEmpty) {
      buf.writeln('\u{1F4CD} ${settings.storeAddress}');
    }
    if (settings.storePhone.isNotEmpty) {
      buf.writeln('\u{1F4DE} ${settings.storePhone}');
    }
    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    if (isReprint) {
      buf.writeln('> \u26A0\uFE0F **DUPLICATE REPRINT**');
      buf.writeln();
    }

    // Metadata
    buf.writeln('## Order: `${order.receiptNo}`');
    buf.writeln();
    buf.writeln('| Field | Value |');
    buf.writeln('|-------|-------|');
    buf.writeln('| **Date / Time** | $dateStr |');
    final cust =
        (order.customerName != null &&
            order.customerName!.trim().isNotEmpty &&
            order.customerName!.trim().toLowerCase() != 'guest')
        ? order.customerName!
        : '...............';
    buf.writeln('| **Customer** | $cust |');
    buf.writeln('| **Payment Method** | ${order.paymentMethod.displayName} |');
    buf.writeln('| **Status** | ${order.status.displayName} |');
    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    // Items Table
    buf.writeln('## \u{1F6D2} Order Items');
    buf.writeln();
    buf.writeln('| # | NAME | QTY | UNIT PRICE | AMOUNT |');
    buf.writeln('|---|------|:---:|:----------:|-------:|');
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      final itemSubtotal = item.unitPrice * item.quantity;
      final discount = itemSubtotal - item.totalPrice;
      final hasDiscount = discount > 0.009;
      final discInfo = hasDiscount
          ? '<br>_Discount: -$curr${discount.toStringAsFixed(2)}_'
          : '';

      buf.writeln(
        '| ${i + 1} | ${item.productName}$discInfo | ${item.quantity} '
        '| $curr${item.unitPrice.toStringAsFixed(2)} '
        '| **$curr${item.totalPrice.toStringAsFixed(2)}** |',
      );
    }
    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    // Totals
    buf.writeln('## \u{1F4B0} Payment Summary');
    buf.writeln();
    buf.writeln('| Description | Amount |');
    buf.writeln('|-------------|-------:|');
    buf.writeln('| Subtotal | $curr${order.subtotal.toStringAsFixed(2)} |');

    if (order.discountAmount > 0) {
      final discLabel = order.discountPercent > 0
          ? 'Discount (${order.discountPercent.toStringAsFixed(0)}%)'
          : 'Discount';
      buf.writeln(
        '| $discLabel | **-$curr${order.discountAmount.toStringAsFixed(2)}** |',
      );
    }

    if (order.taxAmount > 0) {
      buf.writeln(
        '| Tax / VAT (${order.taxRate.toStringAsFixed(0)}%) '
        '| $curr${order.taxAmount.toStringAsFixed(2)} |',
      );
    }

    buf.writeln(
      '| **TOTAL (USD)** | **$curr${order.totalAmount.toStringAsFixed(2)}** |',
    );

    if (settings.showKhrDualCurrency) {
      final khrTotal = NumberFormat('#,###')
          .format((order.totalAmount * settings.usdToKhrRate).round());
      buf.writeln('| **TOTAL (KHR)** | **$khrTotal KHR** |');
    }

    if (order.paymentMethod == PaymentMethod.cash) {
      final tendered = order.cashTendered > 0
          ? order.cashTendered
          : order.totalAmount;
      buf.writeln('| CASH RECEIVED | $curr${tendered.toStringAsFixed(2)} |');
      buf.writeln(
        '| **CHANGE RETURN** | **$curr${order.changeAmount.toStringAsFixed(2)}** |',
      );
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    // Footer
    if (settings.footerNote.isNotEmpty) {
      buf.writeln('> *${settings.footerNote.replaceAll('\n', '*  \n> *')}*');
      buf.writeln();
    }

    buf.writeln('---');
    buf.writeln();
    buf.writeln(
      '_Generated by OmniPOS \u00B7 ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}_',
    );

    return buf.toString();
  }
}
