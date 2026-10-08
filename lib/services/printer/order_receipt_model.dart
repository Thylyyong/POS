import 'dart:typed_data';

import '../../models/order_model.dart';
import '../../models/store_settings_model.dart';

/// Paper width specification for standard thermal POS printers.
enum ReceiptPaperWidth {
  mm58(charsPerLine: 32),
  mm80(charsPerLine: 48);

  final int charsPerLine;
  const ReceiptPaperWidth({required this.charsPerLine});
}

/// Lightweight, immutable DTO for line items on a receipt.
/// Decoupled from database entities and widgets to safely cross Isolate boundaries.
class ReceiptLineItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? notes;

  const ReceiptLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.notes,
  });
}

/// Immutable, serializable receipt payload.
/// Designed for low memory allocation, fast Isolate transfer, and zero UI thread stalls.
class OrderReceiptModel {
  final String receiptNo;
  final String orderNumber;
  final DateTime createdAt;
  final String? tableNumber;
  final String? customerName;
  final String? cashierName;
  final String orderType;

  final List<ReceiptLineItem> items;

  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;

  final String paymentMethod;
  final double cashTendered;
  final double changeAmount;

  final String storeName;
  final String storeAddress;
  final String? storePhone;
  final String currencySymbol;

  final ReceiptPaperWidth paperWidth;
  final bool autoKickDrawer;
  final bool isReprint;
  final bool printLogo;
  final Uint8List? logoImageBytes;
  final String? footerMessage;

  const OrderReceiptModel({
    required this.receiptNo,
    required this.orderNumber,
    required this.createdAt,
    this.tableNumber,
    this.customerName,
    this.cashierName,
    this.orderType = 'DINE_IN',
    required this.items,
    required this.subtotal,
    this.discountAmount = 0.0,
    this.taxAmount = 0.0,
    required this.totalAmount,
    required this.paymentMethod,
    this.cashTendered = 0.0,
    this.changeAmount = 0.0,
    required this.storeName,
    required this.storeAddress,
    this.storePhone,
    this.currencySymbol = '\$',
    this.paperWidth = ReceiptPaperWidth.mm80,
    this.autoKickDrawer = false,
    this.isReprint = false,
    this.printLogo = false,
    this.logoImageBytes,
    this.footerMessage,
  });

  /// Factory adapter to bridge existing domain models into this lean printing DTO.
  factory OrderReceiptModel.fromOrder({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isPaid = true,
    bool isReprint = false,
    Uint8List? logoImageBytes,
  }) {
    return OrderReceiptModel(
      receiptNo: order.receiptNo,
      orderNumber: order.orderNumber ?? order.receiptNo.split('-').last,
      createdAt: order.createdAt,
      tableNumber: order.tableNumber,
      customerName: order.customerName,
      cashierName: order.cashierName,
      orderType: order.orderType,
      items: order.items
          .map(
            (item) => ReceiptLineItem(
              name: item.productName,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              totalPrice: item.totalPrice,
              notes: item.notes,
            ),
          )
          .toList(growable: false),
      subtotal: order.subtotal,
      discountAmount: order.discountAmount,
      taxAmount: order.taxAmount,
      totalAmount: order.totalAmount,
      paymentMethod: order.paymentMethod.displayName,
      cashTendered: order.cashTendered,
      changeAmount: order.changeAmount,
      storeName: settings.storeName.isNotEmpty
          ? settings.storeName
          : 'POS STORE',
      storeAddress: settings.storeAddress,
      currencySymbol: settings.currencySymbol,
      paperWidth: settings.isPaperSize80mm
          ? ReceiptPaperWidth.mm80
          : ReceiptPaperWidth.mm58,
      autoKickDrawer:
          settings.autoKickCashDrawer &&
          order.paymentMethod == PaymentMethod.cash,
      isReprint: isReprint,
      printLogo: settings.printLogoOnReceipt,
      logoImageBytes: logoImageBytes,
      footerMessage: isPaid
          ? '*** THANK YOU FOR YOUR VISIT ***\n*** PLEASE COME AGAIN ***'
          : 'UNPAID BILL / INVOICE\nPlease present at cashier to pay',
    );
  }
}
