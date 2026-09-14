import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/order_model.dart';
import '../models/store_settings_model.dart';
import 'pdf_receipt_service.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

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
              width: settings.isPaperSize80mm ? 260 : 180,
            );
            final grayscale = img.grayscale(resized);
            bytes += generator.imageRaster(grayscale, align: PosAlign.center);
          }
        } catch (_) {}
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
    if (settings.storeAddress.isNotEmpty) {
      bytes += generator.text(
        settings.storeAddress.toUpperCase(),
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
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

    final customerStr = (order.customerName != null &&
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
            final byteData = await rootBundle.load(settings.qrImagePath!.trim());
            rawQrBytes = byteData.buffer.asUint8List();
          } catch (_) {}
        }
        if (rawQrBytes != null && rawQrBytes.isNotEmpty) {
          try {
            final decoded = img.decodeImage(Uint8List.fromList(rawQrBytes));
            if (decoded != null) {
              final resized = img.copyResize(
                decoded,
                width: settings.isPaperSize80mm ? 260 : 180,
              );
              final grayscale = img.grayscale(resized);
              bytes += generator.imageRaster(grayscale, align: PosAlign.center);
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

      bytes += generator.text(
        'Scan with banking app or pay with Cash / Card',
        styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
      );

      bytes += generator.feed(1);
      bytes += generator.hr(ch: '-');
    } else {
      bytes += generator.feed(1);
      bytes += generator.text(
        'UNPAID BILL / INVOICE',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'Please present this bill at cashier counter to pay',
        styles: const PosStyles(align: PosAlign.center, fontType: PosFontType.fontB),
      );
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
      if (preferredName != null &&
          preferredName.trim().isNotEmpty &&
          preferredName.trim().toLowerCase() != 'auto') {
        final match = printers.cast<Printer?>().firstWhere(
          (p) => p != null && p.name.toLowerCase().contains(preferredName.toLowerCase()),
          orElse: () => null,
        );
        if (match != null) return match;
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

      // 2. Keyword scan
      for (final printer in printers) {
        final lower = printer.name.toLowerCase();
        for (final kw in thermalKeywords) {
          if (lower.contains(kw)) {
            return printer;
          }
        }
      }

      // 3. OS default printer (skip virtual document writers)
      final virtualKeywords = ['pdf', 'onenote', 'fax', 'anydesk', 'xps'];
      final defaultPrinter = printers.cast<Printer?>().firstWhere(
        (p) {
          if (p == null || !p.isDefault) return false;
          final lower = p.name.toLowerCase();
          return !virtualKeywords.any((v) => lower.contains(v));
        },
        orElse: () => null,
      );
      if (defaultPrinter != null) return defaultPrinter;

      // 4. Return first physical printer
      return printers.firstWhere(
        (p) {
          final lower = p.name.toLowerCase();
          return !virtualKeywords.any((v) => lower.contains(v));
        },
        orElse: () => printers.first,
      );
    } catch (_) {
      return null;
    }
  }

  /// Automatically verify machine printer connection status
  Future<Map<String, dynamic>> verifyPrinterStatus({String? preferredName}) async {
    try {
      final printer = await autoDetectThermalPrinter(preferredName: preferredName);
      final sumatraPath = await findSumatraPdfExecutable();
      if (printer == null) {
        return {
          'success': false,
          'message': 'No printer detected in Windows. Please check printer driver.',
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

      final pdfBytes = await PdfReceiptService().generateReceiptPdf(
        order: order,
        settings: settings,
        isPaid: isPaid,
        showQr: showQr,
        isReprint: isReprint,
      );

      final printer = await autoDetectThermalPrinter(
        preferredName: settings.selectedPrinterName,
      );
      final targetPrinterName = printer?.name ??
          (settings.selectedPrinterName.isNotEmpty &&
                  settings.selectedPrinterName.toLowerCase() != 'auto'
              ? settings.selectedPrinterName
              : null);

      // 2. On Windows: Try SumatraPDF FIRST (silent, reliable, handles thermal paper without driver crashes)
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

      // 4. Secondary SumatraPDF fallback if direct print failed
      if (Platform.isWindows) {
        final sumatraFallback = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: targetPrinterName,
        );
        if (sumatraFallback) return true;
      }

      // 5. Fallback to system layout print dialog
      try {
        return await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Receipt_${order.receiptNo}.pdf',
        );
      } catch (_) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Direct silent print for Kitchen Ticket (Strictly NO prices or totals)
  Future<bool> printKitchenTicket({
    required OrderModel order,
    required StoreSettingsModel settings,
  }) async {
    try {
      final pdfBytes = await PdfReceiptService().generateKitchenTicketPdf(
        order: order,
        settings: settings,
      );

      final printer = await autoDetectThermalPrinter(
        preferredName: settings.selectedPrinterName,
      );
      final targetPrinterName = printer?.name ??
          (settings.selectedPrinterName.isNotEmpty &&
                  settings.selectedPrinterName.toLowerCase() != 'auto'
              ? settings.selectedPrinterName
              : null);

      // 1. On Windows: Try SumatraPDF FIRST
      if (Platform.isWindows && settings.useSumatraPdf) {
        final sumatraSuccess = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: targetPrinterName,
        );
        if (sumatraSuccess) return true;
      }

      // 2. Direct print via Printing package
      if (printer != null) {
        try {
          final directSuccess = await Printing.directPrintPdf(
            printer: printer,
            onLayout: (format) async => pdfBytes,
          );
          if (directSuccess) return true;
        } catch (_) {}
      }

      // 3. Secondary SumatraPDF fallback
      if (Platform.isWindows) {
        final sumatraFallback = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: targetPrinterName,
        );
        if (sumatraFallback) return true;
      }

      // 4. Fallback to system layout print dialog
      try {
        return await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Kitchen_Ticket_${order.orderNumber ?? order.receiptNo}.pdf',
        );
      } catch (_) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Diagnostic Test Receipt to verify CA H2 built-in printer & auto-cutter
  Future<bool> printTestReceipt({
    required StoreSettingsModel settings,
  }) async {
    try {
      final printer = await autoDetectThermalPrinter(
        preferredName: settings.selectedPrinterName,
      );
      final targetDeviceName = printer?.name ??
          (settings.selectedPrinterName.isNotEmpty &&
                  settings.selectedPrinterName.toLowerCase() != 'auto'
              ? settings.selectedPrinterName
              : 'Auto-Detected');

      final pdfBytes = await PdfReceiptService().generateTestReceiptPdf(
        settings: settings,
        targetDeviceName: targetDeviceName,
      );

      // 1. On Windows: Try SumatraPDF FIRST
      if (Platform.isWindows && settings.useSumatraPdf) {
        final sumatraSuccess = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: printer?.name ??
              (targetDeviceName != 'Auto-Detected' ? targetDeviceName : null),
        );
        if (sumatraSuccess) return true;
      }

      // 2. Direct print via Printing package
      if (printer != null) {
        try {
          final directSuccess = await Printing.directPrintPdf(
            printer: printer,
            onLayout: (format) async => pdfBytes,
          );
          if (directSuccess) return true;
        } catch (_) {}
      }

      // 3. Secondary SumatraPDF fallback
      if (Platform.isWindows) {
        final sumatraFallback = await printWithSumatraPdf(
          pdfBytes: pdfBytes,
          printerName: printer?.name,
        );
        if (sumatraFallback) return true;
      }

      // 4. Fallback to system layout print
      try {
        return await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'Printer_Test_Slip.pdf',
        );
      } catch (_) {
        return false;
      }
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
          Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';

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
        final lines =
            whereResult.stdout.toString().trim().split(RegExp(r'[\r\n]+'));
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

  /// Print a PDF silently using SumatraPDF CLI
  /// Flags: `-print-to "<printer_name>"` (or `-print-to-default`), `-silent`, `-print-settings "noscale"`, `"<pdf_path>"`
  Future<bool> printWithSumatraPdf({
    required List<int> pdfBytes,
    String? printerName,
    bool noScale = true,
  }) async {
    if (!Platform.isWindows) return false;
    final sumatraExe = await findSumatraPdfExecutable();
    if (sumatraExe == null) return false;

    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}\\pos_receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes, flush: true);

      final List<String> args = [];
      final target = printerName?.trim() ?? '';
      final isDefault = target.isEmpty ||
          target.toLowerCase() == 'auto' ||
          target.toLowerCase() == 'default';

      if (isDefault) {
        args.add('-print-to-default');
      } else {
        args.addAll(['-print-to', target]);
      }

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
}
