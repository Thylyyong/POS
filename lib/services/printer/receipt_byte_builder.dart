import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import 'order_receipt_model.dart';
import '../thermal_image_helper.dart';

/// Low-level ESC/POS binary command constants.
abstract final class _EscPos {
  static const List<int> init = [0x1B, 0x40]; // ESC @
  static const List<int> selectCodePage = [0x1B, 0x74, 0x00]; // ESC t 0 (PC437)

  // Alignments
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];

  // Font Weights & Sizes
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  static const List<int> sizeNormal = [0x1D, 0x21, 0x00];
  static const List<int> sizeDoubleBoth = [0x1D, 0x21, 0x11];
  static const List<int> sizeDoubleHeight = [0x1D, 0x21, 0x01];

  // Actions
  static const List<int> lineFeed = [0x0A];
  static const List<int> kickDrawer = [
    0x1B,
    0x70,
    0x00,
    0x19,
    0xFA,
  ]; // Pin 2, 50ms
  static const List<int> cutPaper = [
    0x1D,
    0x56,
    0x42,
    0x00,
  ]; // GS V 66 0 (Feed & Partial Cut)
}

/// Pure Dart ESC/POS byte generator designed to run inside an Isolate.
/// - Zero Flutter UI / widget dependencies.
/// - Generates compact binary payloads (< 3KB) in < 2ms.
/// - Prevents Android thermal printer buffer overruns and OOM issues.
abstract final class ReceiptByteBuilder {
  /// Top-level or static entrypoint for [compute] or background Isolates.
  static Uint8List buildBytes(OrderReceiptModel receipt) {
    final builder = BytesBuilder(copy: false);
    final width = receipt.paperWidth.charsPerLine;

    // 1. Initialize Printer & Set Encoding
    builder.add(_EscPos.init);
    builder.add(_EscPos.selectCodePage);

    // 2. Hardware Trigger: Kick Drawer if configured
    if (receipt.autoKickDrawer) {
      builder.add(_EscPos.kickDrawer);
    }

    // 3. Header: one compact logo with the store name printed as text beside it.
    _writeHeader(builder, receipt, width);

    // 4. Reprint Warning (if applicable)
    if (receipt.isReprint) {
      builder.add(_EscPos.lineFeed);
      builder.add(_EscPos.boldOn);
      _writeAsciiLine(builder, '*** DUPLICATE REPRINT ***');
      builder.add(_EscPos.boldOff);
    }

    // 5. Divider & Order Metadata
    _writeDivider(builder, width);
    builder.add(_EscPos.alignLeft);

    _writeTwoColumnRow(
      builder,
      'ORDER #: ${receipt.orderNumber}',
      'TYPE: ${receipt.orderType}',
      width,
    );
    _writeTwoColumnRow(
      builder,
      'DATE: ${DateFormat('yyyy-MM-dd HH:mm').format(receipt.createdAt)}',
      receipt.tableNumber != null ? 'TBL: ${receipt.tableNumber}' : '',
      width,
    );

    if (receipt.customerName != null &&
        receipt.customerName!.trim().isNotEmpty) {
      _writeAsciiLine(builder, 'CUSTOMER: ${receipt.customerName!.trim()}');
    }
    if (receipt.cashierName != null && receipt.cashierName!.trim().isNotEmpty) {
      _writeAsciiLine(builder, 'CASHIER:  ${receipt.cashierName!.trim()}');
    }

    _writeDivider(builder, width);

    // 6. Line Items Table
    _writeItemHeaders(builder, width);
    _writeDivider(builder, width, char: '-');

    final curr = receipt.currencySymbol;
    for (final item in receipt.items) {
      _writeItemRow(builder, item, curr, width);
    }

    _writeDivider(builder, width, char: '-');

    // 7. Totals & Financials
    builder.add(_EscPos.alignLeft);
    _writeTwoColumnRow(
      builder,
      'SUBTOTAL:',
      '$curr${receipt.subtotal.toStringAsFixed(2)}',
      width,
    );

    if (receipt.discountAmount > 0.009) {
      _writeTwoColumnRow(
        builder,
        'DISCOUNT:',
        '-$curr${receipt.discountAmount.toStringAsFixed(2)}',
        width,
      );
    }
    if (receipt.taxAmount > 0.009) {
      _writeTwoColumnRow(
        builder,
        'TAX / VAT:',
        '$curr${receipt.taxAmount.toStringAsFixed(2)}',
        width,
      );
    }

    // Grand Total (Emphasized)
    builder.add(_EscPos.boldOn);
    builder.add(_EscPos.sizeDoubleHeight);
    _writeTwoColumnRow(
      builder,
      'TOTAL:',
      '$curr${receipt.totalAmount.toStringAsFixed(2)}',
      width,
    );
    builder.add(_EscPos.sizeNormal);
    builder.add(_EscPos.boldOff);

    _writeDivider(builder, width);

    // 8. Payment Breakdown
    _writeTwoColumnRow(
      builder,
      'PAYMENT METHOD:',
      receipt.paymentMethod.toUpperCase(),
      width,
    );
    if (receipt.cashTendered > 0) {
      _writeTwoColumnRow(
        builder,
        'CASH TENDERED:',
        '$curr${receipt.cashTendered.toStringAsFixed(2)}',
        width,
      );
      _writeTwoColumnRow(
        builder,
        'CHANGE:',
        '$curr${receipt.changeAmount.toStringAsFixed(2)}',
        width,
      );
    }

    _writeDivider(builder, width);

    // 9. Footer Note
    if (receipt.footerMessage != null && receipt.footerMessage!.isNotEmpty) {
      builder.add(_EscPos.alignCenter);
      for (final line in receipt.footerMessage!.split('\n')) {
        _writeAsciiLine(builder, line.trim());
      }
    }

    // 10. Feed Lines & Hardware Cut
    builder.add(_EscPos.lineFeed);
    builder.add(_EscPos.lineFeed);
    builder.add(_EscPos.lineFeed);
    builder.add(_EscPos.cutPaper);

    return builder.takeBytes();
  }

  // ---------------------------------------------------------------------------
  // Low-level Layout Helpers
  // ---------------------------------------------------------------------------

  static void _writeHeader(
    BytesBuilder builder,
    OrderReceiptModel receipt,
    int charsPerLine,
  ) {
    img.Image? logo;
    if (receipt.printLogo && receipt.logoImageBytes != null) {
      final decoded = img.decodeImage(receipt.logoImageBytes!);
      if (decoded != null) {
        // Keep the logo compact: thermal heads print raster data much more
        // slowly than the text that follows it. The store name remains text.
        final maxWidth = charsPerLine >= 48 ? 80 : 56;
        logo = img.copyResize(
          decoded,
          width: maxWidth,
          interpolation: img.Interpolation.linear,
        );
        if (logo.height > 40) {
          logo = img.copyResize(
            logo,
            height: 40,
            interpolation: img.Interpolation.linear,
          );
        }
        logo = ThermalImageHelper.convertToMonochromeImage(
          logo,
          threshold: 180,
          useDithering: false,
        );
      }
    }

    if (logo == null) {
      builder.add(_EscPos.alignCenter);
      builder.add(_EscPos.sizeDoubleBoth);
      builder.add(_EscPos.boldOn);
      _writeAsciiLine(builder, receipt.storeName.toUpperCase());
      builder.add(_EscPos.sizeNormal);
      builder.add(_EscPos.boldOff);
    } else {
      builder.add(_EscPos.alignLeft);
      builder.add(_EscPos.boldOn);
      final logoChars = (logo.width + 11) ~/ 12;
      final nameLines = _wrapText(
        receipt.storeName.toUpperCase(),
        charsPerLine - logoChars,
      );
      final logoBands = (logo.height + 23) ~/ 24;
      final bands = logoBands > nameLines.length ? logoBands : nameLines.length;

      for (var band = 0; band < bands; band++) {
        if (band < logoBands) {
          _writeLogoBand(builder, logo, band);
        } else {
          builder.add(_encodeAscii(' ' * logoChars));
        }
        if (band < nameLines.length) {
          builder.add(_encodeAscii(nameLines[band]));
        }
        builder.add(_EscPos.lineFeed);
      }
      builder.add(_EscPos.boldOff);
    }

    if (receipt.storeAddress.isNotEmpty) {
      builder.add(_EscPos.alignCenter);
      _writeAsciiLine(builder, receipt.storeAddress);
    }
    if (receipt.storePhone != null && receipt.storePhone!.isNotEmpty) {
      builder.add(_EscPos.alignCenter);
      _writeAsciiLine(builder, 'Tel: ${receipt.storePhone}');
    }
  }

  static void _writeLogoBand(BytesBuilder builder, img.Image logo, int band) {
    final width = logo.width;
    builder.add([0x1B, 0x2A, 33, width & 0xFF, (width >> 8) & 0xFF]);

    for (var x = 0; x < width; x++) {
      for (var byteIndex = 0; byteIndex < 3; byteIndex++) {
        var value = 0;
        for (var bit = 0; bit < 8; bit++) {
          final y = band * 24 + byteIndex * 8 + bit;
          if (y < logo.height && logo.getPixel(x, y).r < 128) {
            value |= 1 << (7 - bit);
          }
        }
        builder.addByte(value);
      }
    }
  }

  static void _writeAsciiLine(BytesBuilder builder, String text) {
    builder.add(_encodeAscii(text));
    builder.add(_EscPos.lineFeed);
  }

  static void _writeDivider(
    BytesBuilder builder,
    int width, {
    String char = '=',
  }) {
    final divider = char * width;
    _writeAsciiLine(builder, divider);
  }

  static void _writeTwoColumnRow(
    BytesBuilder builder,
    String left,
    String right,
    int width,
  ) {
    final trimmedLeft = left.trim();
    final trimmedRight = right.trim();
    final spaceNeeded = width - (trimmedLeft.length + trimmedRight.length);

    if (spaceNeeded <= 0) {
      _writeAsciiLine(builder, '$trimmedLeft $trimmedRight');
    } else {
      _writeAsciiLine(builder, '$trimmedLeft${' ' * spaceNeeded}$trimmedRight');
    }
  }

  static void _writeItemHeaders(BytesBuilder builder, int width) {
    builder.add(_EscPos.boldOn);
    if (width >= 48) {
      // 80mm format: NAME(26), QTY(4), PRICE(8), TOTAL(10)
      _writeAsciiLine(
        builder,
        'NAME'.padRight(26) +
            'QTY'.padLeft(4) +
            'PRICE'.padLeft(8) +
            'TOTAL'.padLeft(10),
      );
    } else {
      // 58mm format: NAME(14), QTY(3), PRICE(7), TOTAL(8)
      _writeAsciiLine(
        builder,
        'NAME'.padRight(14) +
            'QTY'.padLeft(3) +
            'PRICE'.padLeft(7) +
            'TOTAL'.padLeft(8),
      );
    }
    builder.add(_EscPos.boldOff);
  }

  static void _writeItemRow(
    BytesBuilder builder,
    ReceiptLineItem item,
    String curr,
    int width,
  ) {
    final qtyStr = '${item.quantity}';
    final priceStr = '$curr${item.unitPrice.toStringAsFixed(2)}';
    final totalStr = '$curr${item.totalPrice.toStringAsFixed(2)}';

    if (width >= 48) {
      // 80mm Layout: 26 chars for name
      final nameColWidth = 26;
      final nameLines = _wrapText(item.name, nameColWidth);
      final firstLine = nameLines.first.padRight(nameColWidth);
      _writeAsciiLine(
        builder,
        '$firstLine${qtyStr.padLeft(4)}${priceStr.padLeft(8)}${totalStr.padLeft(10)}',
      );

      for (int i = 1; i < nameLines.length; i++) {
        _writeAsciiLine(builder, nameLines[i]);
      }
    } else {
      // 58mm Layout: 14 chars for name
      final nameColWidth = 14;
      final nameLines = _wrapText(item.name, nameColWidth);
      final firstLine = nameLines.first.padRight(nameColWidth);
      _writeAsciiLine(
        builder,
        '$firstLine${qtyStr.padLeft(3)}${priceStr.padLeft(7)}${totalStr.padLeft(8)}',
      );

      for (int i = 1; i < nameLines.length; i++) {
        _writeAsciiLine(builder, nameLines[i]);
      }
    }

    if (item.notes != null && item.notes!.trim().isNotEmpty) {
      _writeAsciiLine(builder, '  * ${item.notes!.trim()}');
    }
  }

  static List<String> _wrapText(String text, int maxWidth) {
    if (text.length <= maxWidth) return [text];
    final lines = <String>[];
    int start = 0;
    while (start < text.length) {
      int end = start + maxWidth;
      if (end >= text.length) {
        lines.add(text.substring(start));
        break;
      }
      lines.add(text.substring(start, end));
      start = end;
    }
    return lines;
  }

  /// Sanitizes text into clean ISO-8859-1 / ASCII bytes to prevent POS printer unicode corruption.
  static List<int> _encodeAscii(String text) {
    return latin1.encode(
      text.replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF]'), '?'),
    );
  }
}
