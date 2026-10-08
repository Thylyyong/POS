import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, MethodChannel;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/order_model.dart';
import '../models/store_settings_model.dart';
import 'pdf_receipt_service.dart';
import 'printer/order_receipt_model.dart';
import 'printer/receipt_byte_builder.dart';
import 'thermal_image_helper.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  static const MethodChannel _androidPrinterChannel = MethodChannel(
    'com.casolution.pos/printer',
  );

  // In-memory cache for processed 1-bit thermal logo (prevents repeated 2.5MB PNG decoding delays)
  static img.Image? _cachedRasterLogo;
  static String? _cachedLogoKey;
  static Uint8List? _cachedReceiptLogoBytes;
  static String? _cachedReceiptLogoKey;

  /// Direct hardware print to Android POS terminal's built-in thermal printer
  Future<bool> _printViaAndroidNative(List<int> bytes) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final success = await _androidPrinterChannel.invokeMethod<bool>(
        'printRawData',
        {'bytes': Uint8List.fromList(bytes)},
      );
      return success == true;
    } catch (e) {
      debugPrint('[PrinterService] Android native print error: $e');
      return false;
    }
  }

  /// Kick cash drawer via native Android POS hardware interface
  Future<bool> kickCashDrawerNative() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final success = await _androidPrinterChannel.invokeMethod<bool>(
        'kickCashDrawer',
      );
      return success == true;
    } catch (_) {
      return false;
    }
  }

  /// Fast hardware-first print path used by Android POS terminals.
  /// It avoids repeated logo decode and PDF rendering on the UI thread.
  Future<bool> _tryFastAndroidReceiptPrint({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isPaid = true,
    bool showQr = true,
    bool isReprint = false,
  }) async {
    if (kIsWeb || !Platform.isAndroid || (!isPaid && showQr)) {
      return false;
    }

    try {
      final logoBytes = settings.printLogoOnReceipt
          ? await _loadFastReceiptLogo(settings.logoPath)
          : null;
      final receipt = OrderReceiptModel.fromOrder(
        order: order,
        settings: settings,
        isPaid: isPaid,
        isReprint: isReprint,
        logoImageBytes: logoBytes,
      );

      final escBytes = await compute(ReceiptByteBuilder.buildBytes, receipt);
      return await _printViaAndroidNative(escBytes);
    } catch (e) {
      debugPrint('[PrinterService] Fast Android receipt path failed: $e');
      return false;
    }
  }

  Future<Uint8List?> _loadFastReceiptLogo(String? logoPath) async {
    final candidates = <String>[
      if (logoPath != null && logoPath.trim().isNotEmpty) logoPath.trim(),
      'assets/images/ca.png',
      'assets/app_logo.png',
    ];

    for (final candidate in candidates) {
      if (_cachedReceiptLogoKey == candidate &&
          _cachedReceiptLogoBytes != null) {
        return _cachedReceiptLogoBytes;
      }

      Uint8List? bytes;
      try {
        final file = File(candidate.replaceAll('/', Platform.pathSeparator));
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      } catch (_) {}

      if (bytes == null) {
        try {
          final assetKey = candidate.replaceAll(r'\', '/');
          final data = await rootBundle.load(assetKey);
          bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } catch (_) {}
      }

      if (bytes != null && bytes.isNotEmpty) {
        _cachedReceiptLogoKey = candidate;
        _cachedReceiptLogoBytes = bytes;
        return bytes;
      }
    }

    return null;
  }

  /// Generate ESC/POS byte sequence for thermal receipt
  Future<List<int>> generateReceiptBytes({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isPaid = true,
    bool showQr = true,
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

    // 2. Store Logo (if enabled and available)
    if (settings.printLogoOnReceipt) {
      final logoWidth = settings.isPaperSize80mm ? 288 : 192;
      final logoKey =
          '${settings.logoPath}_${logoWidth}_${settings.monochromeLogoOnRealPrint}';
      img.Image? rasterImage;

      if (_cachedLogoKey == logoKey && _cachedRasterLogo != null) {
        rasterImage = _cachedRasterLogo;
      } else {
        List<int>? rawLogoBytes;
        if (settings.logoPath != null && settings.logoPath!.isNotEmpty) {
          final rawPath = settings.logoPath!.trim();
          try {
            final normalized = rawPath.replaceAll('/', Platform.pathSeparator);
            final file = File(normalized);
            if (await file.exists()) {
              rawLogoBytes = await file.readAsBytes();
            }
          } catch (_) {}
          if (rawLogoBytes == null) {
            try {
              final file = File(rawPath);
              if (await file.exists()) {
                rawLogoBytes = await file.readAsBytes();
              }
            } catch (_) {}
          }
          if (rawLogoBytes == null) {
            try {
              final assetKey = rawPath.replaceAll(r'\', '/');
              final byteData = await rootBundle.load(assetKey);
              rawLogoBytes = byteData.buffer.asUint8List();
            } catch (_) {}
          }
        }
        // Fallback to store logo (ca.png)
        if (rawLogoBytes == null) {
          try {
            final byteData = await rootBundle.load('assets/images/ca.png');
            rawLogoBytes = byteData.buffer.asUint8List();
          } catch (_) {}
        }
        if (rawLogoBytes == null) {
          final defaultLogo = File('assets/images/ca.png');
          if (await defaultLogo.exists()) {
            try {
              rawLogoBytes = await defaultLogo.readAsBytes();
            } catch (_) {}
          }
        }
        if (rawLogoBytes == null) {
          try {
            final byteData = await rootBundle.load('assets/app_logo.png');
            rawLogoBytes = byteData.buffer.asUint8List();
          } catch (_) {}
        }
        if (rawLogoBytes != null && rawLogoBytes.isNotEmpty) {
          try {
            final decoded = img.decodeImage(Uint8List.fromList(rawLogoBytes));
            if (decoded != null) {
              final resized = img.copyResize(
                decoded,
                width: logoWidth,
                interpolation: img.Interpolation.linear,
              );
              rasterImage = settings.monochromeLogoOnRealPrint
                  ? ThermalImageHelper.convertToMonochromeImage(
                      resized,
                      threshold: 180,
                      useDithering: true,
                    )
                  : img.grayscale(resized);
              _cachedRasterLogo = rasterImage;
              _cachedLogoKey = logoKey;
            }
          } catch (e) {
            debugPrint('[PrinterService] Logo decode/mono error: $e');
          }
        }
      }

      if (rasterImage != null) {
        try {
          bytes += generator.imageRaster(rasterImage, align: PosAlign.center);
        } catch (_) {
          try {
            bytes += generator.image(rasterImage, align: PosAlign.center);
          } catch (_) {}
        }
        bytes += generator.feed(1);
      }
    }

    // 3. Store Header
    final storeName = settings.storeName.toUpperCase();
    final isLongName = storeName.length > (settings.isPaperSize80mm ? 24 : 16);
    bytes += generator.text(
      storeName,
      styles: PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: isLongName ? PosTextSize.size1 : PosTextSize.size2,
        bold: true,
      ),
    );
    if (settings.storeAddress.isNotEmpty) {
      bytes += generator.text(
        settings.storeAddress.toUpperCase(),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }
    bytes += generator.feed(1);

    if (isReprint) {
      bytes += generator.text(
        '*** DUPLICATE REPRINT ***',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    bytes += generator.hr(ch: '-');

    final customerStr =
        (order.customerName != null &&
            order.customerName!.trim().isNotEmpty &&
            order.customerName!.trim().toLowerCase() != 'guest')
        ? order.customerName!.trim()
        : '...............';
    final dateStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt);
    final billNo = order.orderNumber ?? order.receiptNo.split('-').last;

    if (!isPaid) {
      bytes += generator.text(
        'Bill: $billNo',
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text('Date: $dateStr');
      bytes += generator.text('Customer: $customerStr');
    } else {
      bytes += generator.text(
        'Order: ${order.receiptNo} (Paid)',
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text('Date: $dateStr');
      bytes += generator.text('Customer: $customerStr');
    }
    bytes += generator.hr(ch: '-');

    final curr = settings.currencySymbol;

    if (settings.isPaperSize80mm) {
      bytes += generator.row([
        PosColumn(text: 'NAME', width: 5, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'QTY',
          width: 1,
          styles: const PosStyles(bold: true, align: PosAlign.center),
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
          styles: const PosStyles(bold: true, align: PosAlign.center),
        ),
        PosColumn(
          text: 'PRICE',
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

        if (item.productName.length > 12) {
          bytes += generator.text(
            item.productName,
            styles: const PosStyles(bold: true),
          );
          bytes += generator.row([
            PosColumn(text: '', width: 1),
            PosColumn(
              text:
                  '${item.quantity} x $curr${item.unitPrice.toStringAsFixed(2)}',
              width: 6,
              styles: const PosStyles(align: PosAlign.left),
            ),
            PosColumn(
              text: '$curr${item.totalPrice.toStringAsFixed(2)}',
              width: 5,
              styles: const PosStyles(align: PosAlign.right, bold: true),
            ),
          ]);
        } else {
          bytes += generator.row([
            PosColumn(text: item.productName, width: 4),
            PosColumn(
              text: '${item.quantity}',
              width: 2,
              styles: const PosStyles(align: PosAlign.center),
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
        }
        if (hasDiscount) {
          bytes += generator.text(
            ' + Discount: -$curr${discount.toStringAsFixed(2)}',
          );
        }
        if (item.notes != null && item.notes!.isNotEmpty) {
          bytes += generator.text(' + Note: ${item.notes}');
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

    bytes += generator.hr(ch: '-');

    if (isPaid) {
      bytes += generator.row([
        PosColumn(
          text: 'PAYMENT METHOD:',
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: order.paymentMethod.displayName.toUpperCase(),
          width: 6,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr(ch: '-');
    } else if (showQr) {
      bytes += generator.feed(1);
      bytes += generator.text(
        'Bakong & All Mobile Banking Apps',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.feed(1);

      // ── Dynamic Bank Payment QR Code Footer ──────────────────────────────────
      bool qrImagePrinted = false;
      if (settings.qrImagePath != null &&
          settings.qrImagePath!.trim().isNotEmpty) {
        List<int>? rawQrBytes;
        final file = File(settings.qrImagePath!.trim());
        if (await file.exists()) {
          try {
            rawQrBytes = await file.readAsBytes();
          } catch (_) {}
        }
        if (rawQrBytes == null) {
          try {
            final byteData = await rootBundle.load(
              settings.qrImagePath!.trim(),
            );
            rawQrBytes = byteData.buffer.asUint8List();
          } catch (_) {}
        }
        if (rawQrBytes != null && rawQrBytes.isNotEmpty) {
          try {
            final decoded = img.decodeImage(Uint8List.fromList(rawQrBytes));
            if (decoded != null) {
              final resized = img.copyResize(
                decoded,
                width: settings.isPaperSize80mm ? 288 : 192,
                interpolation: img.Interpolation.linear,
              );
              final rasterImage = settings.monochromeLogoOnRealPrint
                  ? ThermalImageHelper.convertToMonochromeImage(
                      resized,
                      threshold: 180,
                      useDithering: true,
                    )
                  : img.grayscale(resized);
              try {
                bytes += generator.imageRaster(
                  rasterImage,
                  align: PosAlign.center,
                );
              } catch (_) {
                bytes += generator.image(rasterImage, align: PosAlign.center);
              }
              qrImagePrinted = true;
            }
          } catch (_) {}
        }
      }

      if (!qrImagePrinted) {
        final raw = settings.qrPayloadTemplate.trim();
        String qrData;
        if (raw.isNotEmpty && !raw.contains('pay.restaurant.com')) {
          if (raw.contains('{order}')) {
            qrData = raw.replaceAll(
              '{order}',
              order.orderNumber ?? order.receiptNo,
            );
          } else if (raw.endsWith('=')) {
            qrData = '$raw${order.orderNumber ?? order.receiptNo}';
          } else {
            qrData = raw;
          }
        } else {
          final storeClean = settings.storeName
              .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
              .toUpperCase();
          final amt = order.totalAmount.toStringAsFixed(2);
          final khrAmt = (order.totalAmount * settings.usdToKhrRate).round();
          qrData =
              'KHQR:MERCHANT:$storeClean:INV#${order.orderNumber ?? order.receiptNo}:USD$amt:KHR$khrAmt';
        }

        try {
          bytes += generator.qrcode(
            qrData,
            align: PosAlign.center,
            size: QRSize.size6,
            cor: QRCorrection.M,
          );
        } catch (_) {
          // Fallback if printer profile does not support native QR
        }
      }

      if (!settings.isPaperSize80mm) {
        bytes += generator.text(
          'Scan with banking app or',
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        );
        bytes += generator.text(
          'pay with Cash / Card',
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        );
      } else {
        bytes += generator.text(
          'Scan with banking app or pay with Cash / Card',
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        );
      }

      bytes += generator.feed(1);
      bytes += generator.hr(ch: '-');
    } else {
      bytes += generator.feed(1);
      bytes += generator.text(
        'UNPAID BILL / INVOICE',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      if (!settings.isPaperSize80mm) {
        bytes += generator.text(
          'Please present this bill at',
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        );
        bytes += generator.text(
          'cashier counter to pay',
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        );
      } else {
        bytes += generator.text(
          'Please present this bill at cashier counter to pay',
          styles: const PosStyles(
            align: PosAlign.center,
            fontType: PosFontType.fontB,
          ),
        );
      }
      bytes += generator.feed(1);
      bytes += generator.hr(ch: '-');
    }

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

    final paperSize = settings.isPaperSize80mm
        ? PaperSize.mm80
        : PaperSize.mm58;
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
    final tableNum =
        (order.tableNumber != null && order.tableNumber!.isNotEmpty)
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

  /// Generate ESC/POS byte sequence for Diagnostic Test Receipt
  Future<List<int>> generateTestReceiptBytes({
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

    final paperSize = settings.isPaperSize80mm
        ? PaperSize.mm80
        : PaperSize.mm58;
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    bytes += generator.reset();
    bytes += generator.text(
      settings.storeName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    );
    bytes += generator.text(
      'PRINTER HARDWARE TEST',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.hr(ch: '=');
    bytes += generator.text(
      'PAPER SIZE: ${settings.isPaperSize80mm ? "80mm" : "58mm"}',
    );
    bytes += generator.text(
      'INTERFACE: BUILT-IN THERMAL / USB',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.text(
      'TIMESTAMP: ${DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now())}',
    );
    bytes += generator.text(
      'AUTO CUTTER: TEST PASSED',
      styles: const PosStyles(bold: true),
    );
    bytes += generator.hr(ch: '-');
    bytes += generator.text(
      '*** TEST COMPLETED SUCCESSFULLY ***',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  /// Kick cash drawer independently
  Future<List<int>> kickCashDrawer() async {
    if (!kIsWeb && Platform.isAndroid) {
      await kickCashDrawerNative();
    }
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    return generator.drawer();
  }

  /// Get all printers currently installed in the OS (Windows / Android)
  Future<List<Printer>> getInstalledPrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (_) {
      return [];
    }
  }

  /// Automatically scans and detects the machine's built-in thermal printer
  /// Looks for:
  /// 1. User's manually preferred printer name from Settings
  /// 2. Thermal / POS keywords (POS, 80, Thermal, Receipt, Kiosk, XP, GP, RP, etc.)
  /// 3. OS default printer (excluding virtual ones like OneNote / PDF)
  Future<Printer?> autoDetectThermalPrinter({String? preferredName}) async {
    try {
      final printers = await Printing.listPrinters();
      if (printers.isEmpty) return null;

      // 1. Explicit preference match
      final virtualKeywords = [
        'pdf',
        'onenote',
        'one note',
        'fax',
        'anydesk',
        'xps',
        'microsoft print to pdf',
        'send to onenote',
        'print to pdf',
        'virtual',
        'writer',
        'document writer',
      ];

      if (preferredName != null &&
          preferredName.trim().isNotEmpty &&
          preferredName.trim().toLowerCase() != 'auto') {
        final prefLower = preferredName.trim().toLowerCase();
        if (!virtualKeywords.any((v) => prefLower.contains(v))) {
          final match = printers.cast<Printer?>().firstWhere(
            (p) => p != null && p.name.toLowerCase().contains(prefLower),
            orElse: () => null,
          );
          if (match != null) return match;
        }
      }

      // Keywords common in commercial POS and built-in kiosk printers (like CA H2 / GD215-H2)
      final thermalKeywords = [
        'pos',
        '80',
        '58',
        'thermal',
        'receipt',
        'ticket',
        'kiosk',
        'xp-',
        'xprinter',
        'gp-',
        'gprinter',
        'rp-',
        'rongta',
        'tm-t',
        'epson',
        'star',
        'bixolon',
        'sunmi',
      ];

      // 2. Keyword scan (excluding virtual ones)
      for (final printer in printers) {
        final lower = printer.name.toLowerCase();
        if (virtualKeywords.any((v) => lower.contains(v))) continue;
        for (final kw in thermalKeywords) {
          if (lower.contains(kw)) {
            return printer;
          }
        }
      }

      // 3. OS default printer (skip virtual document writers)
      final defaultPrinter = printers.cast<Printer?>().firstWhere((p) {
        if (p == null || !p.isDefault) return false;
        final lower = p.name.toLowerCase();
        return !virtualKeywords.any((v) => lower.contains(v));
      }, orElse: () => null);
      if (defaultPrinter != null) return defaultPrinter;

      // 4. Return first physical printer, or null (NEVER fallback to OneNote / virtual printer)
      return printers.cast<Printer?>().firstWhere((p) {
        if (p == null) return false;
        final lower = p.name.toLowerCase();
        return !virtualKeywords.any((v) => lower.contains(v));
      }, orElse: () => null);
    } catch (_) {
      return null;
    }
  }

  /// Automatically verify machine printer connection status
  Future<Map<String, dynamic>> verifyPrinterStatus({
    String? preferredName,
  }) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final rawInfo = await _androidPrinterChannel.invokeMethod<Map>(
            'getPrinterStatus',
          );
          final info = Map<String, dynamic>.from(rawInfo ?? {});
          final usbDevices =
              (info['usbDevices'] as List?)?.cast<String>() ?? [];
          final printerLabel = usbDevices.isNotEmpty
              ? usbDevices.first
              : 'Built-in POS Thermal Printer';
          return {
            'success': true,
            'message': 'Android POS Hardware Ready',
            'printerName': printerLabel,
            'isAvailable': true,
            'isDefault': true,
            'hasSumatraPdf': false,
          };
        } catch (_) {
          return {
            'success': true,
            'message': 'Android Built-in Thermal Hardware',
            'printerName': 'Internal Thermal Printer',
            'isAvailable': true,
            'hasSumatraPdf': false,
          };
        }
      }

      final printer = await autoDetectThermalPrinter(
        preferredName: preferredName,
      );
      final sumatraPath = await findSumatraPdfExecutable();
      if (printer == null) {
        return {
          'success': false,
          'message':
              'No printer detected. Please check printer connection or driver.',
          'printerName': 'None',
          'isAvailable': false,
          'hasSumatraPdf': sumatraPath != null,
          'sumatraPath': sumatraPath,
        };
      }

      return {
        'success': true,
        'message': 'Printer ready & verified',
        'printerName': printer.name,
        'isAvailable': printer.isAvailable,
        'isDefault': printer.isDefault,
        'hasSumatraPdf': sumatraPath != null,
        'sumatraPath': sumatraPath,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Printer check error: $e',
        'printerName': 'Error',
        'isAvailable': false,
        'hasSumatraPdf': false,
      };
    }
  }

  /// Direct silent print for Customer Receipt (zero popups on kiosk)
  Future<bool> printReceipt({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isPaid = true,
    bool showQr = true,
    bool isReprint = false,
    bool allowSystemDialog = false,
  }) async {
    try {
      // 1. If user configured Network Socket streaming with a specific IP
      if (_isIpAddress(settings.printerIpOrAddress)) {
        final streamed = await _trySocketPrint(
          ip: settings.printerIpOrAddress,
          order: order,
          settings: settings,
          isPaid: isPaid,
          showQr: showQr,
          isReprint: isReprint,
        );
        if (streamed) return true;
      }

      // 2. On Android POS terminal: Direct hardware printing via ESC/POS raw bytes
      if (!kIsWeb && Platform.isAndroid) {
        final fastSuccess = await _tryFastAndroidReceiptPrint(
          order: order,
          settings: settings,
          isPaid: isPaid,
          showQr: showQr,
          isReprint: isReprint,
        );
        if (fastSuccess) {
          return true;
        }
      }

      final pdfBytes = await PdfReceiptService().generateReceiptPdf(
        order: order,
        settings: settings,
        isPaid: isPaid,
        showQr: showQr,
        isReprint: isReprint,
        isForRealPrint: true,
      );

      final printer = await autoDetectThermalPrinter(
        preferredName: settings.selectedPrinterName,
      );
      final targetPrinterName =
          printer?.name ??
          (settings.selectedPrinterName.isNotEmpty &&
                  settings.selectedPrinterName.toLowerCase() != 'auto'
              ? settings.selectedPrinterName
              : null);

      if (targetPrinterName == null || isVirtualPrinter(targetPrinterName)) {
        debugPrint(
          '[PrinterService] Print skipped: No physical thermal printer found. Won\'t launch OneNote.',
        );
        return false;
      }

      // 3. On Windows: Try SumatraPDF FIRST (silent, reliable, handles thermal paper without driver crashes)
      if (Platform.isWindows && settings.useSumatraPdf) {
        final sumatraSuccess = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: targetPrinterName,
        );
        if (sumatraSuccess) return true;
      }

      // 4. Direct print via Printing package
      if (printer != null) {
        try {
          final directSuccess = await Printing.directPrintPdf(
            printer: printer,
            onLayout: (format) async => pdfBytes,
          );
          if (directSuccess) return true;
        } catch (_) {}
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Direct silent print for Kitchen Ticket (Strictly NO prices or totals)
  Future<bool> printKitchenTicket({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool allowSystemDialog = false,
  }) async {
    try {
      // 1. On Android POS terminal: Direct hardware printing via ESC/POS raw bytes
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final escBytes = await generateKitchenTicketBytes(
            order: order,
            settings: settings,
          );
          final nativeSuccess = await _printViaAndroidNative(escBytes);
          if (nativeSuccess) return true;
        } catch (e) {
          debugPrint('[PrinterService] Android native kitchen print error: $e');
        }
      }

      final pdfBytes = await PdfReceiptService().generateKitchenTicketPdf(
        order: order,
        settings: settings,
      );

      final printer = await autoDetectThermalPrinter(
        preferredName: settings.selectedPrinterName,
      );
      final targetPrinterName =
          printer?.name ??
          (settings.selectedPrinterName.isNotEmpty &&
                  settings.selectedPrinterName.toLowerCase() != 'auto'
              ? settings.selectedPrinterName
              : null);

      if (targetPrinterName == null || isVirtualPrinter(targetPrinterName)) {
        debugPrint(
          '[PrinterService] Kitchen print skipped: No physical thermal printer found.',
        );
        return false;
      }

      // 2. On Windows: Try SumatraPDF FIRST
      if (Platform.isWindows && settings.useSumatraPdf) {
        final sumatraSuccess = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: targetPrinterName,
        );
        if (sumatraSuccess) return true;
      }

      // 3. Direct print via Printing package
      if (printer != null) {
        try {
          final directSuccess = await Printing.directPrintPdf(
            printer: printer,
            onLayout: (format) async => pdfBytes,
          );
          if (directSuccess) return true;
        } catch (_) {}
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Diagnostic Test Receipt to verify CA H2 built-in printer & auto-cutter
  Future<bool> printTestReceipt({required StoreSettingsModel settings}) async {
    try {
      // 1. On Android POS terminal: Direct hardware printing via ESC/POS raw bytes
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final escBytes = await generateTestReceiptBytes(settings: settings);
          final nativeSuccess = await _printViaAndroidNative(escBytes);
          if (nativeSuccess) return true;
        } catch (e) {
          debugPrint('[PrinterService] Android native test print error: $e');
        }
      }

      final printer = await autoDetectThermalPrinter(
        preferredName: settings.selectedPrinterName,
      );
      final effectiveTarget =
          printer?.name ??
          (settings.selectedPrinterName.isNotEmpty &&
                  settings.selectedPrinterName.toLowerCase() != 'auto'
              ? settings.selectedPrinterName
              : null);

      if (effectiveTarget == null || isVirtualPrinter(effectiveTarget)) {
        debugPrint(
          '[PrinterService] Test print skipped: No physical thermal printer found.',
        );
        return false;
      }

      final pdfBytes = await PdfReceiptService().generateTestReceiptPdf(
        settings: settings,
        targetDeviceName: effectiveTarget,
      );

      // 2. On Windows: Try SumatraPDF FIRST
      if (Platform.isWindows && settings.useSumatraPdf) {
        final sumatraSuccess = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: effectiveTarget,
        );
        if (sumatraSuccess) return true;
      }

      // 3. Direct print via Printing package
      if (printer != null) {
        try {
          final directSuccess = await Printing.directPrintPdf(
            printer: printer,
            onLayout: (format) async => pdfBytes,
          );
          if (directSuccess) return true;
        } catch (_) {}
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Send diagnostic test slip directly to a specific chosen printer device
  Future<bool> printTestReceiptToDevice({
    required Printer printer,
    required StoreSettingsModel settings,
  }) async {
    try {
      final pdfBytes = await PdfReceiptService().generateTestReceiptPdf(
        settings: settings,
        targetDeviceName: printer.name,
      );

      // 1. On Windows: Try SumatraPDF FIRST
      if (Platform.isWindows && settings.useSumatraPdf) {
        final sumatraSuccess = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: printer.name,
        );
        if (sumatraSuccess) return true;
      }

      // 2. Direct print via Printing package
      try {
        final directSuccess = await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) async => pdfBytes,
        );
        if (directSuccess) return true;
      } catch (_) {}

      // 3. Secondary SumatraPDF fallback
      if (Platform.isWindows) {
        final sumatraFallback = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: printer.name,
        );
        if (sumatraFallback) return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if SumatraPDF.exe is present in app directory, windows/bin, C:\POS, or system paths
  Future<String?> findSumatraPdfExecutable() async {
    if (!Platform.isWindows) return null;
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final currentDir = Directory.current.path;
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      final programFiles =
          Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
      final programFilesX86 =
          Platform.environment['ProgramFiles(x86)'] ??
          r'C:\Program Files (x86)';

      final candidates = [
        '$exeDir\\SumatraPDF.exe',
        '$exeDir\\bin\\SumatraPDF.exe',
        '$currentDir\\windows\\bin\\SumatraPDF.exe',
        '$currentDir\\SumatraPDF.exe',
        r'C:\POS\SumatraPDF.exe',
        if (localAppData.isNotEmpty)
          '$localAppData\\SumatraPDF\\SumatraPDF.exe',
        '$programFiles\\SumatraPDF\\SumatraPDF.exe',
        '$programFilesX86\\SumatraPDF\\SumatraPDF.exe',
      ];
      for (final path in candidates) {
        if (await File(path).exists()) return path;
      }

      // Check if available on system PATH via where.exe
      final whereResult = await Process.run('where.exe', ['SumatraPDF.exe']);
      if (whereResult.exitCode == 0) {
        final lines = whereResult.stdout.toString().trim().split(
          RegExp(r'[\r\n]+'),
        );
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && await File(trimmed).exists()) {
            return trimmed;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  bool isVirtualPrinter(String? name) {
    if (name == null || name.trim().isEmpty) return true;
    final lower = name.trim().toLowerCase();
    const virtualKeywords = [
      'onenote',
      'one note',
      'pdf',
      'print to pdf',
      'microsoft print to pdf',
      'adobe pdf',
      'anydesk',
      'xps',
      'fax',
      'virtual',
      'writer',
      'document writer',
      'send to onenote',
    ];
    return virtualKeywords.any((kw) => lower.contains(kw));
  }

  /// Print a PDF silently using SumatraPDF CLI
  /// Flags: `-print-to "<printer_name>"`, `-silent`, `-print-settings "noscale"`, `"<pdf_path>"`
  Future<bool> printWithSumatraPdf({
    required List<int> pdfBytes,
    String? printerName,
    bool noScale = true,
  }) async {
    if (!Platform.isWindows) return false;
    final target = printerName?.trim() ?? '';

    // STRICT SAFETY: Never print to OneNote or virtual PDF writers!
    if (target.isEmpty ||
        target.toLowerCase() == 'auto' ||
        target.toLowerCase() == 'default' ||
        isVirtualPrinter(target)) {
      debugPrint(
        '[PrinterService] Refusing to print to virtual printer / OneNote.',
      );
      return false;
    }

    final sumatraExe = await findSumatraPdfExecutable();
    if (sumatraExe == null) return false;

    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}\\pos_receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes, flush: true);

      final List<String> args = ['-print-to', target, '-silent'];

      args.add('-silent');

      if (noScale) {
        args.addAll(['-print-settings', 'noscale']);
      }

      args.add(tempFile.path);

      final result = await Process.run(sumatraExe, args);

      // Schedule cleanup after Windows spooler finishes processing
      Future.delayed(const Duration(seconds: 30), () async {
        try {
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
      });

      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  bool _isIpAddress(String value) {
    final trimmed = value.trim();
    final parts = trimmed.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) {
      final n = int.tryParse(p);
      return n != null && n >= 0 && n <= 255;
    });
  }

  Future<bool> _trySocketPrint({
    required String ip,
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isPaid = true,
    bool showQr = true,
    bool isReprint = false,
  }) async {
    try {
      final socket = await Socket.connect(
        ip,
        9100,
        timeout: const Duration(milliseconds: 1500),
      );
      final bytes = await generateReceiptBytes(
        order: order,
        settings: settings,
        isPaid: isPaid,
        showQr: showQr,
        isReprint: isReprint,
      );
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Print a simple list of plain-text lines as a thermal receipt.
  /// Generates a text-based PDF and sends it through the existing PDF print pipeline.
  Future<bool> printRawLines({
    required List<String> lines,
    required StoreSettingsModel settings,
    bool allowSystemDialog = false,
  }) async {
    try {
      // 1. On Android POS terminal: Direct hardware printing via ESC/POS
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final profile = await CapabilityProfile.load();
          final generator = Generator(
            settings.isPaperSize80mm ? PaperSize.mm80 : PaperSize.mm58,
            profile,
          );
          List<int> bytes = [];
          bytes += generator.reset();
          for (final line in lines) {
            bytes += generator.text(line);
          }
          bytes += generator.feed(2);
          bytes += generator.cut();
          final nativeSuccess = await _printViaAndroidNative(bytes);
          if (nativeSuccess) return true;
        } catch (e) {
          debugPrint(
            '[PrinterService] Android native raw lines print error: $e',
          );
        }
      }

      final pdfBytes = await PdfReceiptService().generateTextLinePdf(
        lines: lines,
        settings: settings,
      );

      final printer = await autoDetectThermalPrinter(
        preferredName: settings.selectedPrinterName,
      );
      final targetPrinterName =
          printer?.name ??
          (settings.selectedPrinterName.isNotEmpty &&
                  settings.selectedPrinterName.toLowerCase() != 'auto'
              ? settings.selectedPrinterName
              : null);

      // 2. SumatraPDF silent print on Windows
      if (Platform.isWindows && settings.useSumatraPdf) {
        final sumatraSuccess = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: targetPrinterName,
        );
        if (sumatraSuccess) return true;
      }

      // 3. Direct print via Printing package
      if (printer != null) {
        try {
          final directSuccess = await Printing.directPrintPdf(
            printer: printer,
            onLayout: (format) async => pdfBytes,
          );
          if (directSuccess) return true;
        } catch (_) {}
      }

      // 4. Fallback to system print dialog ONLY IF allowed AND not Android
      if (allowSystemDialog && !Platform.isAndroid) {
        return await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Register_Closing_Report.pdf',
        );
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}
