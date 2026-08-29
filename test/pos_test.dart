import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/controllers/cart_controller.dart';
import 'package:pos_flutter/models/order_model.dart';
import 'package:pos_flutter/models/product_model.dart';
import 'package:pos_flutter/models/store_settings_model.dart';
import 'package:pos_flutter/services/presentation_service.dart';
import 'package:pos_flutter/services/printer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartController Unit Tests', () {
    late CartController cart;
    final testProductA = Product(
      id: 'p1',
      categoryId: 'c1',
      name: 'Espresso',
      price: 3.00,
      cost: 1.00,
    );
    final testProductB = Product(
      id: 'p2',
      categoryId: 'c1',
      name: 'Croissant',
      price: 4.50,
      cost: 1.50,
    );

    setUp(() {
      cart = CartController();
      cart.updateConfig(taxRate: 10.0, currencySymbol: '\$');
    });

    test('Adding products updates item count and subtotal correctly', () {
      cart.addProduct(testProductA, quantity: 2); // 2 * 3.00 = 6.00
      cart.addProduct(testProductB, quantity: 1); // 1 * 4.50 = 4.50

      expect(cart.totalItemCount, 3);
      expect(cart.subtotal, 10.50);
    });

    test('Applying percentage discount calculates discount and tax correctly', () {
      cart.addProduct(testProductA, quantity: 2); // 6.00
      cart.addProduct(testProductB, quantity: 2); // 9.00 -> subtotal = 15.00

      cart.setDiscountPercent(20.0); // 20% of 15.00 = 3.00 discount
      expect(cart.discountAmount, 3.00);
      expect(cart.subtotalAfterDiscount, 12.00);

      // Tax = 10% of 12.00 = 1.20
      expect(cart.taxAmount, closeTo(1.20, 0.001));
      // Total = 12.00 + 1.20 = 13.20
      expect(cart.totalAmount, closeTo(13.20, 0.001));
    });

    test('Applying fixed discount calculates properly', () {
      cart.addProduct(testProductA, quantity: 4); // 12.00
      cart.setDiscountFixed(2.00);

      expect(cart.discountAmount, 2.00);
      expect(cart.subtotalAfterDiscount, 10.00);
      expect(cart.taxAmount, 1.00);
      expect(cart.totalAmount, 11.00);
    });

    test('Hold and Recall order works seamlessly', () {
      cart.addProduct(testProductA, quantity: 2);
      expect(cart.totalItemCount, 2);

      final held = cart.holdCurrentCart();
      expect(held, true);
      expect(cart.isEmpty, true);
      expect(cart.heldCarts.length, 1);

      cart.recallHeldCart(0);
      expect(cart.totalItemCount, 2);
      expect(cart.heldCarts.isEmpty, true);
    });
  });

  group('Presentation Payload JSON Serialization Tests', () {
    test('Payload converts to and from JSON without data loss', () {
      final original = PresentationPayload(
        state: CfdScreenState.cartActive,
        items: [
          {'productId': 'p1', 'productName': 'Wagyu Burger', 'quantity': 2, 'unitPrice': 12.5, 'totalPrice': 25.0}
        ],
        subtotal: 25.0,
        discountAmount: 2.5,
        taxAmount: 2.25,
        totalAmount: 24.75,
        currencySymbol: '\$',
        receiptNo: 'REC-20260826-0001',
      );

      final jsonStr = original.toJson();
      final reconstructed = PresentationPayload.fromJson(jsonStr);

      expect(reconstructed.state, CfdScreenState.cartActive);
      expect(reconstructed.subtotal, 25.0);
      expect(reconstructed.discountAmount, 2.5);
      expect(reconstructed.totalAmount, 24.75);
      expect(reconstructed.receiptNo, 'REC-20260826-0001');
      expect(reconstructed.items.length, 1);
    });
  });

  group('PrinterService Thermal ESC/POS Byte Generation Tests', () {
    test('generateReceiptBytes produces valid non-empty byte sequence', () async {
      final printerService = PrinterService();
      final order = OrderModel(
        id: 'ord_test_01',
        receiptNo: 'REC-20260826-0099',
        subtotal: 20.00,
        discountAmount: 0.0,
        taxAmount: 2.00,
        taxRate: 10.0,
        totalAmount: 22.00,
        paymentMethod: PaymentMethod.cash,
        cashTendered: 30.00,
        changeAmount: 8.00,
        items: [
          OrderItemModel(
            id: 'item_1',
            orderId: 'ord_test_01',
            productId: 'p1',
            productName: 'Double Espresso',
            quantity: 2,
            unitPrice: 3.00,
            totalPrice: 6.00,
          ),
        ],
      );

      const settings = StoreSettingsModel(
        storeName: 'Test Bistro',
        isPaperSize80mm: true,
        autoKickCashDrawer: true,
      );

      final bytes = await printerService.generateReceiptBytes(
        order: order,
        settings: settings,
      );

      expect(bytes.isNotEmpty, true);
      expect(bytes.length, greaterThan(20));
    });
  });

  group('StoreSettingsModel Display & Template Tests', () {
    test('Stores and serializes custom font scale and grid template', () {
      const model = StoreSettingsModel(
        storeName: 'Artisan Cafe',
        fontSizeScale: 1.15,
        gridTemplate: '3x6',
      );

      final map = model.toMap();
      expect(map['font_size_scale'], '1.15');
      expect(map['grid_template'], '3x6');

      final reconstructed = StoreSettingsModel.fromMap(map);
      expect(reconstructed.fontSizeScale, 1.15);
      expect(reconstructed.gridTemplate, '3x6');
    });
  });
}
