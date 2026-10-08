import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pos_flutter/models/order_model.dart';
import 'package:pos_flutter/models/store_settings_model.dart';
import 'package:pos_flutter/services/printer/order_receipt_model.dart';
import 'package:pos_flutter/services/printer/receipt_byte_builder.dart';

void main() {
  test('receipt byte builder produces printable bytes without hanging on heavy assets', () {
    final now = DateTime(2024, 1, 1, 12, 0, 0);
    final order = OrderModel(
      id: '1',
      receiptNo: 'R-1001',
      orderNumber: '1001',
      createdAt: now,
      customerName: 'Alice',
      cashierName: 'Cashier',
      orderType: 'DINE_IN',
      paymentMethod: PaymentMethod.cash,
      subtotal: 20.0,
      discountAmount: 0.0,
      taxAmount: 2.0,
      totalAmount: 22.0,
      cashTendered: 25.0,
      changeAmount: 3.0,
      items: [
        OrderItemModel(
          id: '1',
          orderId: '1',
          productId: 'p1',
          productName: 'Coffee',
          quantity: 2,
          unitPrice: 9.0,
          totalPrice: 18.0,
          notes: 'No sugar',
        ),
      ],
    );

    final settings = StoreSettingsModel(
      storeName: 'CAFE POS',
      storeAddress: 'Main Street',
      currencySymbol: '\$',
      isPaperSize80mm: true,
      autoKickCashDrawer: true,
      autoPrintOnPayment: true,
      printLogoOnReceipt: true,
    );

    final logo = img.Image(width: 24, height: 24);
    logo.setPixelRgba(12, 12, 0, 0, 0, 255);

    final receipt = OrderReceiptModel.fromOrder(
      order: order,
      settings: settings,
      isPaid: true,
      logoImageBytes: Uint8List.fromList(img.encodePng(logo)),
    );

    final bytes = ReceiptByteBuilder.buildBytes(receipt);
    expect(bytes, isNotEmpty);
    expect(bytes.first, 0x1B);
    expect(bytes, contains(0x0A));
    expect(bytes, containsAllInOrder([0x1B, 0x2A, 33]));
    expect(bytes, containsAllInOrder('CAFE POS'.codeUnits));
  });
}
