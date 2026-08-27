import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../models/store_settings_model.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  /// Generate ESC/POS byte sequence for thermal receipt
  Future<List<int>> generateReceiptBytes({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isReprint = false,
  }) async {
    final profile = await CapabilityProfile.load();
    final paperSize = settings.isPaperSize80mm ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // Reset printer
    bytes += generator.reset();

    // 1. Kick Cash Drawer if configured and cash payment
    if (settings.autoKickCashDrawer && order.paymentMethod == PaymentMethod.cash) {
      bytes += generator.drawer();
    }

    // 2. Store Logo (if available)
    if (settings.logoPath != null && settings.logoPath!.isNotEmpty) {
      final file = File(settings.logoPath!);
      if (await file.exists()) {
        try {
          final imageBytes = await file.readAsBytes();
          final decoded = img.decodeImage(imageBytes);
          if (decoded != null) {
            final resized = img.copyResize(
              decoded,
              width: settings.isPaperSize80mm ? 300 : 200,
            );
            final grayscale = img.grayscale(resized);
            bytes += generator.imageRaster(grayscale, align: PosAlign.center);
          }
        } catch (_) {
          // Fallback if image rendering fails
        }
      }
    }

    // 3. Store Header
    bytes += generator.text(
      settings.storeName,
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );

    if (settings.storeAddress.isNotEmpty) {
      bytes += generator.text(
        settings.storeAddress,
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    if (settings.storePhone.isNotEmpty) {
      bytes += generator.text(
        'Tel: ${settings.storePhone}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.feed(1);

    // 4. Reprint / Original Banner
    if (isReprint) {
      bytes += generator.text(
        '*** DUPLICATE REPRINT ***',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    // 5. Receipt Metadata
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt);
    bytes += generator.hr(ch: '=');
    bytes += generator.text('Receipt #: ${order.receiptNo}', styles: const PosStyles(bold: true));
    bytes += generator.text('Date: $dateStr');
    bytes += generator.text('Payment: ${order.paymentMethod.displayName}');
    bytes += generator.hr(ch: '-');

    // 6. Itemized Lines
    if (settings.isPaperSize80mm) {
      // 80mm column layout: Item (7), Qty (2), Price (3)
      bytes += generator.row([
        PosColumn(text: 'ITEM', width: 7, styles: const PosStyles(bold: true)),
        PosColumn(text: 'QTY', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(text: 'AMOUNT', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.hr(ch: '-');

      for (var item in order.items) {
        final itemTotal = '${settings.currencySymbol}${item.totalPrice.toStringAsFixed(2)}';
        bytes += generator.row([
          PosColumn(text: item.productName, width: 7),
          PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: itemTotal, width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
    } else {
      // 58mm compact layout
      bytes += generator.text('ITEM                 QTY   AMT', styles: const PosStyles(bold: true));
      bytes += generator.hr(ch: '-');

      for (var item in order.items) {
        final line = '${item.productName.padRight(18).substring(0, 18)} ${item.quantity.toString().padLeft(3)} ${settings.currencySymbol}${item.totalPrice.toStringAsFixed(2).padLeft(6)}';
        bytes += generator.text(line);
      }
    }

    bytes += generator.hr(ch: '=');

    // 7. Subtotal, Discount, Tax, Total
    final curr = settings.currencySymbol;
    bytes += generator.text(
      'Subtotal:'.padRight(16) + '$curr${order.subtotal.toStringAsFixed(2)}'.padLeft(16),
      styles: const PosStyles(align: PosAlign.right),
    );

    if (order.discountAmount > 0) {
      final discLabel = order.discountPercent > 0
          ? 'Discount (${order.discountPercent.toStringAsFixed(0)}%):'
          : 'Discount:';
      bytes += generator.text(
        discLabel.padRight(16) + '-$curr${order.discountAmount.toStringAsFixed(2)}'.padLeft(16),
        styles: const PosStyles(align: PosAlign.right),
      );
    }

    if (order.taxAmount > 0) {
      bytes += generator.text(
        'Tax/VAT (${order.taxRate.toStringAsFixed(0)}%):'.padRight(16) + '$curr${order.taxAmount.toStringAsFixed(2)}'.padLeft(16),
        styles: const PosStyles(align: PosAlign.right),
      );
    }

    bytes += generator.hr(ch: '-');

    // TOTAL AMOUNT
    bytes += generator.text(
      'TOTAL: $curr${order.totalAmount.toStringAsFixed(2)}',
      styles: const PosStyles(
        align: PosAlign.right,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );

    // Tendered & Change
    if (order.paymentMethod == PaymentMethod.cash) {
      bytes += generator.text(
        'Cash Tendered:'.padRight(16) + '$curr${order.cashTendered.toStringAsFixed(2)}'.padLeft(16),
        styles: const PosStyles(align: PosAlign.right),
      );
      bytes += generator.text(
        'Change Due:'.padRight(16) + '$curr${order.changeAmount.toStringAsFixed(2)}'.padLeft(16),
        styles: const PosStyles(align: PosAlign.right, bold: true),
      );
    }

    bytes += generator.feed(1);

    // 8. Barcode / QR Code for receipt verification
    try {
      bytes += generator.barcode(Barcode.code128(order.receiptNo.codeUnits), align: PosAlign.center);
    } catch (_) {
      // Fallback if barcode encoding fails
    }

    bytes += generator.feed(1);

    // 9. Footer Note
    if (settings.footerNote.isNotEmpty) {
      for (var line in settings.footerNote.split('\n')) {
        bytes += generator.text(line, styles: const PosStyles(align: PosAlign.center));
      }
    }

    bytes += generator.text('*** Powered by OmniPOS ***', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  /// Kick cash drawer independently
  Future<List<int>> kickCashDrawer() async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    return generator.drawer();
  }

  /// Print or Mock Print Dispatcher
  Future<bool> printReceipt({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isReprint = false,
  }) async {
    try {
      final bytes = await generateReceiptBytes(
        order: order,
        settings: settings,
        isReprint: isReprint,
      );

      // In production POS terminals with Serial/USB/Network printer:
      // The bytes are dispatched to printer socket / USB endpoint / native printer service.
      // E.g.: Socket.connect(settings.printerIpOrAddress, 9100)...
      // We retain the full binary ESC/POS stream.
      return bytes.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

