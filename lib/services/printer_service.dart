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

    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt);
    bytes += generator.hr(ch: '-');
    bytes += generator.text(
      'Order: ${order.receiptNo}',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text('Date: $dateStr');
    final customer =
        (order.customerName != null &&
            order.customerName!.trim().isNotEmpty &&
            order.customerName!.trim().toLowerCase() != 'guest')
        ? order.customerName!
        : '...............';
    bytes += generator.text('Customer: $customer');
    bytes += generator.hr(ch: '-');

    final curr = settings.currencySymbol;

    if (settings.isPaperSize80mm) {
      bytes += generator.row([
        PosColumn(text: 'NAME', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'QTY',
          width: 1,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'UNIT PRICE',
          width: 3,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
        PosColumn(
          text: 'AMOUNT',
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
        PosColumn(text: 'NAME', width: 4, styles: const PosStyles(bold: true)),
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
          text: 'AMT',
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
      PosColumn(text: 'SUBTOTAL:', width: 6),
      PosColumn(
        text: '$curr${order.subtotal.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL (USD):',
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
          text: 'TOTAL (KHR):',
          width: 5,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: '$khrTotal KHR',
          width: 7,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr(ch: '=');
    bytes += generator.row([
      PosColumn(text: 'PAYMENT METHOD:', width: 6),
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
        PosColumn(text: 'CASH RECEIVED:', width: 6),
        PosColumn(
          text: '$curr${tendered.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'CHANGE RETURN:', width: 6),
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
      '***THANK YOU FOR YOUR VISIT***',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      '***Please Come Again***',
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
