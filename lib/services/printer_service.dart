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
    CapabilityProfile profile;
    try {
      final profileName = (settings.printerProfile.toLowerCase() == 'epson')
          ? 'TM-T88V'
          : settings.printerProfile;
      profile = await CapabilityProfile.load(name: profileName);
    } catch (_) {
      profile = await CapabilityProfile.load();
    }

    final paperSize = settings.isPaperSize80mm
        ? PaperSize.mm80
        : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // Reset printer
    bytes += generator.reset();

    // 1. Kick Cash Drawer if configured and cash payment
    if (settings.autoKickCashDrawer &&
        order.paymentMethod == PaymentMethod.cash) {
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
      settings.storeName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.feed(1);

    if (isReprint) {
      bytes += generator.text(
        '*** DUPLICATE REPRINT ***',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    bytes += generator.hr(ch: '-');
    bytes += generator.text(
      'Order: #${order.orderNumber ?? order.receiptNo}',
      styles: const PosStyles(bold: true),
    );
    final orderTypeStr = order.orderType == 'TAKEAWAY'
        ? 'Takeaway'
        : (order.tableNumber != null && order.tableNumber!.isNotEmpty
            ? 'Dine-In (${order.tableNumber})'
            : 'Dine-In');
    bytes += generator.text('Order Type: $orderTypeStr');
    final dateStr = DateFormat('dd/MM/yyyy, hh:mm:ss a').format(order.createdAt);
    bytes += generator.text('Date: $dateStr');
    bytes += generator.text('Cashier: System Admin');
    if (order.customerName != null &&
        order.customerName!.trim().isNotEmpty &&
        order.customerName!.trim().toLowerCase() != 'guest') {
      bytes += generator.text('Customer: ${order.customerName!}');
    }
    bytes += generator.hr(ch: '-');

    final curr = settings.currencySymbol;

    if (settings.isPaperSize80mm) {
      bytes += generator.row([
        PosColumn(text: 'ITEM', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'QTY',
          width: 1,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'PRICE',
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'TOTAL',
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr(ch: '-');
      for (var item in order.items) {
        final itemSubtotal = item.unitPrice * item.quantity;
        final discount = itemSubtotal - item.totalPrice;
        final hasDiscount = discount > 0.009;

        bytes += generator.row([
          PosColumn(text: item.productName, width: 5),
          PosColumn(
            text: '${item.quantity}',
            width: 1,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: '$curr${item.unitPrice.toStringAsFixed(2)}',
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: '$curr${item.totalPrice.toStringAsFixed(2)}',
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
        if (hasDiscount) {
          bytes += generator.text(
            ' + Discount: -$curr${discount.toStringAsFixed(2)}',
          );
        }
        if (item.notes != null && item.notes!.isNotEmpty) {
          bytes += generator.text(' + Note: ${item.notes}');
        }
      }
    } else {
      bytes += generator.row([
        PosColumn(text: 'ITEM', width: 4, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'QTY',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'PRICE',
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'TOTAL',
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr(ch: '-');
      for (var item in order.items) {
        final itemSubtotal = item.unitPrice * item.quantity;
        final discount = itemSubtotal - item.totalPrice;
        final hasDiscount = discount > 0.009;

        bytes += generator.row([
          PosColumn(text: item.productName, width: 4),
          PosColumn(
            text: '${item.quantity}',
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: '$curr${item.unitPrice.toStringAsFixed(2)}',
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: '$curr${item.totalPrice.toStringAsFixed(2)}',
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
        if (hasDiscount) {
          bytes += generator.text(
            ' + Discount: -$curr${discount.toStringAsFixed(2)}',
          );
        }
      }
    }

    bytes += generator.hr(ch: '-');
    bytes += generator.row([
      PosColumn(text: 'Subtotal:', width: 6),
      PosColumn(
        text: '$curr${order.subtotal.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: 'Total (\$):',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: '$curr${order.totalAmount.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);
    if (settings.showKhrDualCurrency) {
      final khrTotal = NumberFormat('#,###')
          .format((order.totalAmount * settings.usdToKhrRate).round());
      bytes += generator.row([
        PosColumn(
          text: 'Total (KHR):',
          width: 5,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'KHR $khrTotal',
          width: 7,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr(ch: '-');
    bytes += generator.row([
      PosColumn(text: 'Payment Method:', width: 6),
      PosColumn(
        text: order.paymentMethod.displayName.toUpperCase(),
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    if (order.paymentMethod == PaymentMethod.cash) {
      final tendered = order.cashTendered > 0
          ? order.cashTendered
          : order.totalAmount;
      bytes += generator.row([
        PosColumn(text: 'Cash Received:', width: 6),
        PosColumn(
          text: '$curr${tendered.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Change Return:', width: 6),
        PosColumn(
          text: '$curr${order.changeAmount.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr(ch: '-');
    bytes += generator.feed(1);
    bytes += generator.text(
      'SCAN TO PAY WITH KHQR',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Bakong & All Mobile Banking Apps',
      styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
    );
    bytes += generator.feed(1);

    // ── Dynamic QR Code Footer ──────────────────────────────────────────────
    final qrData = (settings.qrPayloadTemplate.isNotEmpty)
        ? '${settings.qrPayloadTemplate}${order.receiptNo}'
        : 'REC:${order.receiptNo}';
    try {
      bytes += generator.qrcode(
        qrData,
        align: PosAlign.center,
        size: QRSize.size4,
        cor: QRCorrection.M,
      );
      bytes += generator.text(
        'Scan with banking app or pay with Cash / Card',
        styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
      );
    } catch (_) {
      // Fallback if printer profile does not support native QR
    }

    bytes += generator.feed(1);
    bytes += generator.hr(ch: '-');
    bytes += generator.feed(1);
    bytes += generator.text(
      '*** Thank you for your visit ***',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Please come again',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  /// Generate ESC/POS byte sequence for Kitchen Ticket (Strictly NO prices or totals)
  Future<List<int>> generateKitchenTicketBytes({
    required OrderModel order,
    required StoreSettingsModel settings,
  }) async {
    CapabilityProfile profile;
    try {
      final profileName = (settings.printerProfile.toLowerCase() == 'epson')
          ? 'TM-T88V'
          : settings.printerProfile;
      profile = await CapabilityProfile.load(name: profileName);
    } catch (_) {
      profile = await CapabilityProfile.load();
    }

    final paperSize = settings.isPaperSize80mm ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    bytes += generator.reset();

    // 1. Header
    bytes += generator.text(
      '*** KITCHEN ORDER ***',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.feed(1);

    // 2. Metadata (Table, Order #, Type, Time)
    final orderNum = order.orderNumber ?? order.receiptNo.split('-').last;
    final tableNum = (order.tableNumber != null && order.tableNumber!.isNotEmpty)
        ? order.tableNumber!
        : (order.orderType == 'TAKEAWAY' ? 'TAKEAWAY' : 'COUNTER');

    bytes += generator.text(
      'ORDER #: $orderNum',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'TABLE: $tableNum',
      styles: const PosStyles(
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text('TYPE: ${order.orderType}');
    bytes += generator.text(
      'TIME: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt)}',
    );
    if (order.customerName != null &&
        order.customerName!.trim().isNotEmpty &&
        order.customerName!.trim().toLowerCase() != 'guest') {
      bytes += generator.text('CUSTOMER: ${order.customerName}');
    }

    bytes += generator.hr(ch: '=');
    bytes += generator.text(
      'ITEMS TO PREPARE',
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.hr(ch: '-');

    // 3. Items list with large bold text (Strictly NO prices or totals)
    for (var item in order.items) {
      bytes += generator.text(
        '${item.quantity}x ${item.productName.toUpperCase()}',
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      if (item.notes != null && item.notes!.trim().isNotEmpty) {
        bytes += generator.text(
          '   ** SPECIAL NOTE: ${item.notes} **',
          styles: const PosStyles(bold: true),
        );
      }
      bytes += generator.feed(1);
    }

    bytes += generator.hr(ch: '=');
    bytes += generator.text(
      '--- KITCHEN COPY ---',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
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

  /// Print or Mock Print Dispatcher for Customer Receipt
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
      return bytes.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Print Kitchen Ticket Dispatcher
  Future<bool> printKitchenTicket({
    required OrderModel order,
    required StoreSettingsModel settings,
  }) async {
    try {
      final bytes = await generateKitchenTicketBytes(
        order: order,
        settings: settings,
      );
      return bytes.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
