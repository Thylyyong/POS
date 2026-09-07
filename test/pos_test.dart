import 'package:flutter_test/flutter_test.dart';
import 'package:pos_flutter/controllers/auth_controller.dart';
import 'package:pos_flutter/controllers/cart_controller.dart';
import 'package:pos_flutter/database/order_dao.dart';
import 'package:pos_flutter/models/accounting_model.dart';
import 'package:pos_flutter/models/order_model.dart';
import 'package:pos_flutter/models/product_model.dart';
import 'package:pos_flutter/models/register_session_model.dart';
import 'package:pos_flutter/models/store_settings_model.dart';
import 'package:pos_flutter/models/user_model.dart';
import 'package:pos_flutter/services/excel_export_service.dart';
import 'package:pos_flutter/services/pdf_receipt_service.dart';
import 'package:pos_flutter/services/presentation_service.dart';
import 'package:pos_flutter/services/printer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthController RBAC & PIN Tests', () {
    late AuthController auth;

    setUp(() {
      auth = AuthController();
    });

    test('Initial user defaults to Staff Cashier', () {
      expect(auth.currentUser.role, UserRole.cashier);
      expect(auth.isCashier, true);
      expect(auth.isMainBoss, false);
      expect(auth.canAccessAccounting, false);
    });

    test('Main Boss login with correct PIN (9999) succeeds', () {
      final mainBoss = AuthController.defaultUsers.first;
      final success = auth.loginWithUserAndPin(mainBoss, '9999');

      expect(success, true);
      expect(auth.currentUser.role, UserRole.mainBoss);
      expect(auth.isMainBoss, true);
      expect(auth.canAccessAccounting, true);
      expect(auth.canSwitchBranch, true);
    });

    test('Sub Boss 1 login with PIN (1111) sets branch to store_a', () {
      final subBoss1 = AuthController.defaultUsers[1];
      final success = auth.loginWithUserAndPin(subBoss1, '1111');

      expect(success, true);
      expect(auth.currentUser.role, UserRole.subBoss);
      expect(auth.isSubBoss, true);
      expect(auth.currentBranchId, 'store_a');
      expect(auth.canAccessAccounting, true);
      expect(auth.canSwitchBranch, false);
    });

    test('Sub Boss 2 login with PIN (2222) sets branch to store_b', () {
      final subBoss2 = AuthController.defaultUsers[2];
      final success = auth.loginWithUserAndPin(subBoss2, '2222');

      expect(success, true);
      expect(auth.currentUser.role, UserRole.subBoss);
      expect(auth.currentBranchId, 'store_b');
    });

    test('Incorrect PIN fails authentication', () {
      final mainBoss = AuthController.defaultUsers.first;
      final success = auth.loginWithUserAndPin(mainBoss, '0000');

      expect(success, false);
      expect(auth.currentUser.role, UserRole.cashier); // Still previous user
    });
  });

  group('RegisterSession & Denomination Tests', () {
    test('Denomination calculator sums total correctly', () {
      final item1 = DenominationItem(value: 200.0, label: '\$200', count: 1);
      final item2 = DenominationItem(value: 100.0, label: '\$100', count: 1);
      final item3 = DenominationItem(value: 20.0, label: '\$20', count: 2);
      final item4 = DenominationItem(value: 5.0, label: '\$5', count: 1);

      final total = item1.total + item2.total + item3.total + item4.total;
      expect(total, 345.00);
    });

    test(
      'RegisterSessionModel calculates expected cash and discrepancy correctly',
      () {
        final session = RegisterSessionModel(
          id: 'sess_test_01',
          branchId: 'store_a',
          branchName: 'Store Branch A',
          cashierId: 'cashier_01',
          cashierName: 'Staff Cashier',
          openedAt: DateTime.now(),
          openingCash: 300.00,
          closingCashCounted: 450.00,
          totalCashSales: 200.00,
          totalCashIn: 50.00,
          totalCashOut: 100.00,
        );

        // Expected Cash = 300 (Opening) + 200 (Cash Sales) + 50 (Cash In) - 100 (Cash Out) = 450.00
        expect(session.calculatedExpectedCash, 450.00);
        // Discrepancy = 450 (Counted) - 450 (Expected) = 0.00 (Balanced)
        expect(session.calculatedCashDifference, 0.00);
      },
    );

    test('RegisterSessionModel detects cash shortage correctly', () {
      final session = RegisterSessionModel(
        id: 'sess_test_02',
        branchId: 'store_a',
        branchName: 'Store Branch A',
        cashierId: 'cashier_01',
        cashierName: 'Staff Cashier',
        openedAt: DateTime.now(),
        openingCash: 300.00,
        closingCashCounted: 420.00, // Counted is $30 short
        totalCashSales: 200.00,
        totalCashIn: 0.00,
        totalCashOut: 50.00,
      );

      // Expected Cash = 300 + 200 - 50 = 450.00
      expect(session.calculatedExpectedCash, 450.00);
      // Difference = 420 - 450 = -30.00
      expect(session.calculatedCashDifference, -30.00);
    });
  });

  group('Odoo Profit & Loss (P&L) and Hybrid Royalty Model Tests', () {
    test('Sub Boss Branch P&L with Hybrid Rent and Royalty calculates Net Income accurately', () {
      final report = ProfitLossReportModel(
        periodLabel: 'September 2026',
        branchId: 'store_a',
        branchName: 'Store Branch A (Downtown)',
        isConsolidated: false,
        grossSalesRevenue: 45280.00,
        costOfSales: 18120.00,
        operatingExpenses: 4200.00,
        baseRentPaidToMainBoss: 500.00, // Fixed Low Base Rent
        salesRoyaltyPaidToMainBoss: 1358.40, // 3.0% of $45,280
        otherIncome: 240.00,
        otherExpenses: 0.0,
      );

      // Gross Profit = 45,280 - 18,120 = 27,160.00
      expect(report.grossProfit, 27160.00);

      // Total Hybrid to Main Boss = 500 + 1,358.40 = 1,858.40
      expect(report.totalHybridSettlementToMainBoss, 1858.40);

      // Total Direct Expenses = 4,200 + 1,858.40 = 6,058.40
      expect(report.totalDirectExpenses, 6058.40);

      // Net Operating Income = 27,160.00 - 6,058.40 = 21,101.60
      expect(report.netOperatingIncome, closeTo(21101.60, 0.01));

      // Net Income = 21,101.60 + 240.00 = 21,341.60
      expect(report.netIncome, closeTo(21341.60, 0.01));
    });

    test(
      'Main Boss Consolidated Executive P&L aggregates inflows properly',
      () {
        final report = ProfitLossReportModel(
          periodLabel: 'September 2026',
          branchId: 'all',
          branchName: 'Consolidated Enterprise',
          isConsolidated: true,
          grossSalesRevenue: 83780.00, // Store A ($45,280) + Store B ($38,500)
          costOfSales: 33520.00,
          operatingExpenses: 300.00, // Central Cloud / Admin costs
          totalRentCollected: 1000.00, // $500 (Store A) + $500 (Store B)
          totalRoyaltiesCollected: 2513.40, // $1,358.40 + $1,155.00
        );

        // Main Boss Gross Franchise Inflow = $1,000 + $2,513.40 = $3,513.40
        expect(report.mainBossGrossInflow, closeTo(3513.40, 0.01));

        // Main Boss Net Inflow = $3,513.40 - $300 = $3,213.40
        expect(report.mainBossNetInflow, closeTo(3213.40, 0.01));
      },
    );
  });

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

    test(
      'Applying percentage discount calculates discount and tax correctly',
      () {
        cart.addProduct(testProductA, quantity: 2); // 6.00
        cart.addProduct(testProductB, quantity: 2); // 9.00 -> subtotal = 15.00

        cart.setDiscountPercent(20.0); // 20% of 15.00 = 3.00 discount
        expect(cart.discountAmount, 3.00);
        expect(cart.subtotalAfterDiscount, 12.00);

        // Tax = 10% of 12.00 = 1.20
        expect(cart.taxAmount, closeTo(1.20, 0.001));
        // Total = 12.00 + 1.20 = 13.20
        expect(cart.totalAmount, closeTo(13.20, 0.001));
      },
    );

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
          {
            'productId': 'p1',
            'productName': 'Wagyu Burger',
            'quantity': 2,
            'unitPrice': 12.5,
            'totalPrice': 25.0,
          },
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
    test(
      'generateReceiptBytes produces valid non-empty byte sequence',
      () async {
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
          storeName: 'CA SOLUTION POS',
          isPaperSize80mm: true,
          printerProfile: 'epson',
          usdToKhrRate: 4000.0,
          showKhrDualCurrency: true,
          autoKickCashDrawer: true,
        );

        final bytes = await printerService.generateReceiptBytes(
          order: order,
          settings: settings,
        );

        expect(bytes.isNotEmpty, true);
        expect(bytes.length, greaterThan(20));
      },
    );

    test(
      'generateReceiptBytes produces valid 58mm compact byte sequence',
      () async {
        final printerService = PrinterService();
        final order = OrderModel(
          id: 'ord_test_02',
          receiptNo: 'SAL-20260904-0001',
          subtotal: 15.00,
          discountAmount: 2.00,
          taxAmount: 1.30,
          taxRate: 10.0,
          totalAmount: 14.30,
          paymentMethod: PaymentMethod.cash,
          cashTendered: 20.00,
          changeAmount: 5.70,
          items: [
            OrderItemModel(
              id: 'item_2',
              orderId: 'ord_test_02',
              productId: 'p2',
              productName: 'Croissant Butter',
              quantity: 1,
              unitPrice: 4.50,
              totalPrice: 4.50,
            ),
          ],
        );

        const settings = StoreSettingsModel(
          storeName: 'CA SOLUTION POS',
          isPaperSize80mm: false,
          printerProfile: 'epson',
          usdToKhrRate: 4000.0,
          showKhrDualCurrency: true,
        );

        final bytes = await printerService.generateReceiptBytes(
          order: order,
          settings: settings,
        );

        expect(bytes.isNotEmpty, true);
        expect(bytes.length, greaterThan(20));
      },
    );

    test(
      'PdfReceiptService generates valid 80mm and 58mm PDF receipts',
      () async {
        final pdfService = PdfReceiptService();
        final order = OrderModel(
          id: 'ord_test_03',
          receiptNo: 'SAL-20260904-0002',
          subtotal: 30.00,
          discountAmount: 0.0,
          taxAmount: 3.00,
          taxRate: 10.0,
          totalAmount: 33.00,
          paymentMethod: PaymentMethod.cash,
          cashTendered: 33.00,
          changeAmount: 0.00,
          items: [
            OrderItemModel(
              id: 'item_3',
              orderId: 'ord_test_03',
              productId: 'p3',
              productName: 'Woodford Reserve',
              quantity: 1,
              unitPrice: 30.00,
              totalPrice: 30.00,
            ),
          ],
        );

        // 80mm PDF
        const settings80 = StoreSettingsModel(
          storeName: 'CA SOLUTION POS',
          isPaperSize80mm: true,
          showKhrDualCurrency: true,
          usdToKhrRate: 4000.0,
        );
        final pdf80 = await pdfService.generateReceiptPdf(
          order: order,
          settings: settings80,
        );
        expect(pdf80.isNotEmpty, true);

        // 58mm PDF
        const settings58 = StoreSettingsModel(
          storeName: 'CA SOLUTION POS',
          isPaperSize80mm: false,
          showKhrDualCurrency: true,
          usdToKhrRate: 4000.0,
        );
        final pdf58 = await pdfService.generateReceiptPdf(
          order: order,
          settings: settings58,
        );
        expect(pdf58.isNotEmpty, true);
      },
    );
  });

  group('StoreSettingsModel Display & Template Tests', () {
    test('Stores and serializes custom font scale and grid template', () {
      const model = StoreSettingsModel(
        storeName: 'CA SOLUTION POS',
        fontSizeScale: 1.15,
        gridTemplate: '3x6',
        isPaperSize80mm: false,
        printerProfile: 'epson',
        usdToKhrRate: 4100.0,
        showKhrDualCurrency: true,
      );

      final map = model.toMap();
      expect(map['font_size_scale'], '1.15');
      expect(map['grid_template'], '3x6');
      expect(map['is_paper_size_80mm'], '0');
      expect(map['printer_profile'], 'epson');
      expect(map['usd_to_khr_rate'], '4100.0');
      expect(map['show_khr_dual_currency'], '1');

      final reconstructed = StoreSettingsModel.fromMap(map);
      expect(reconstructed.fontSizeScale, 1.15);
      expect(reconstructed.gridTemplate, '3x6');
      expect(reconstructed.isPaperSize80mm, false);
      expect(reconstructed.printerProfile, 'epson');
      expect(reconstructed.usdToKhrRate, 4100.0);
      expect(reconstructed.showKhrDualCurrency, true);
    });
  });

  group('ExcelExportService Tests', () {
    test('exportSalesReport generates valid report file', () async {
      final exportService = ExcelExportService();
      final metrics = SalesMetrics(
        totalRevenue: 150.0,
        totalCost: 60.0,
        grossProfit: 90.0,
        totalOrders: 5,
        totalItemsSold: 12,
        averageOrderValue: 30.0,
        cashRevenue: 100.0,
        qrRevenue: 50.0,
        cashOrderCount: 3,
        qrOrderCount: 2,
      );

      const settings = StoreSettingsModel(
        storeName: 'OmniPOS Test Store',
        currencySymbol: '\$',
      );

      final filePath = await exportService.exportSalesReport(
        metrics: metrics,
        orders: [],
        topItems: [],
        logs: [],
        settings: settings,
      );

      expect(filePath.isNotEmpty, true);
      expect(filePath.endsWith('.xlsx'), true);
    });
  });
}
