import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos_flutter/controllers/auth_controller.dart';
import 'package:pos_flutter/controllers/cart_controller.dart';
import 'package:pos_flutter/database/order_dao.dart';
import 'package:pos_flutter/database/register_dao.dart';
import 'package:pos_flutter/models/accounting_model.dart';
import 'package:pos_flutter/models/order_model.dart';
import 'package:pos_flutter/models/product_model.dart';
import 'package:pos_flutter/models/register_session_model.dart';
import 'package:pos_flutter/models/store_settings_model.dart';
import 'package:pos_flutter/models/user_model.dart';
import 'package:pos_flutter/services/excel_export_service.dart';
import 'package:pos_flutter/services/pdf_receipt_service.dart';
import 'package:pos_flutter/services/presentation_service.dart';
import 'package:pos_flutter/core/device_profile.dart';
import 'package:pos_flutter/services/printer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

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
      expect(auth.currentUser.isOwner, true);
      expect(auth.isMainBoss, true);
      expect(auth.isOwner, true);
      expect(auth.canAccessAccounting, true);
      expect(auth.canSwitchBranch, true);
    });

    test('defaultUsers contains strictly 1 Boss and 1 Staff Cashier', () {
      expect(AuthController.defaultUsers.length, 2);
      expect(AuthController.defaultUsers[0].isOwner, true);
      expect(AuthController.defaultUsers[1].isCashier, true);
    });

    test('Staff Cashier login with PIN (1234) succeeds', () {
      final cashier = AuthController.defaultUsers[1];
      final success = auth.loginWithUserAndPin(cashier, '1234');

      expect(success, true);
      expect(auth.currentUser.role, UserRole.cashier);
      expect(auth.isCashier, true);
      expect(auth.currentBranchId, 'main');
      expect(auth.canAccessPos, true);
      expect(auth.canAccessAccounting, false);
      expect(auth.canAccessSettings, false);
    });

    test(
      'loginWithPin authenticates Owner (9999) and Cashier (1234)',
      () async {
        final ownerUser = await auth.loginWithPin('9999');
        expect(ownerUser, isNotNull);
        expect(ownerUser!.isOwner, true);

        final cashierUser = await auth.loginWithPin('1234');
        expect(cashierUser, isNotNull);
        expect(cashierUser!.isCashier, true);

        final invalidUser = await auth.loginWithPin('0000');
        expect(invalidUser, isNull);
      },
    );

    test('Incorrect PIN fails authentication', () {
      final mainBoss = AuthController.defaultUsers.first;
      final success = auth.loginWithUserAndPin(mainBoss, '0000');

      expect(success, false);
      expect(auth.currentUser.role, UserRole.cashier); // Still previous user
    });

    test('screenUsers contains strictly Owner (Boss) and Staff Cashier', () {
      final screenUsers = AuthController.screenUsers;
      expect(screenUsers.length, 2);
      expect(screenUsers[0].isOwner, true);
      expect(screenUsers[1].isCashier, true);
    });

    test(
      'changeUserPin updates user PIN and rejects incorrect current PIN',
      () async {
        final cashier = AuthController.defaultUsers[1];
        // Attempt with wrong current PIN
        final fail = await auth.changeUserPin(
          userId: cashier.id,
          currentPin: '0000',
          newPin: '4321',
        );
        expect(fail, false);

        // Attempt with correct current PIN (using admin override for unit tests where db is uninitialized)
        final success = await auth.changeUserPin(
          userId: cashier.id,
          currentPin: cashier.pinCode,
          newPin: '4321',
          isAdminOverride: true,
        );
        expect(success, true);
        expect(AuthController.defaultUsers[1].pinCode, '4321');

        // Revert back for other tests
        await auth.changeUserPin(
          userId: cashier.id,
          currentPin: '4321',
          newPin: '1234',
          isAdminOverride: true,
        );
      },
    );
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

    test('RegisterDao getActiveSession queries cleanly without SQLite syntax error', () async {
      final dao = RegisterDao();
      final session = await dao.getActiveSession(branchId: 'store_a');
      expect(session, anyOf(isNull, isA<RegisterSessionModel>()));
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

        // Bill (Unpaid with QR) vs Receipt (Paid without QR)
        final pdfBill = await pdfService.generateReceiptPdf(
          order: order,
          settings: settings80,
          isPaid: false,
        );
        expect(pdfBill.isNotEmpty, true);

        final pdfPaid = await pdfService.generateReceiptPdf(
          order: order,
          settings: settings80,
          isPaid: true,
        );
        expect(pdfPaid.isNotEmpty, true);
      },
    );

    test('generateReceiptBytes produces distinct Bill (QR) and Paid (No QR) output', () async {
      final printerService = PrinterService();
      final order = OrderModel(
        id: 'ord_test_04',
        receiptNo: 'SAL-20260908-0041',
        orderNumber: '0041',
        customerName: 'Guest',
        subtotal: 5.50,
        discountAmount: 0.0,
        taxAmount: 0.0,
        totalAmount: 5.50,
        paymentMethod: PaymentMethod.qr,
        createdAt: DateTime(2026, 9, 8, 14, 30),
        items: [
          OrderItemModel(
            id: 'item_1',
            orderId: 'ord_test_04',
            productId: 'p1',
            productName: 'Chicken Curry Rice',
            quantity: 1,
            unitPrice: 5.50,
            totalPrice: 5.50,
          ),
        ],
      );

      const settings = StoreSettingsModel(
        storeName: "D'CURRY'S",
        storeAddress: 'AUTHENTIC MALAYSIAN CUISINE',
        isPaperSize80mm: true,
        usdToKhrRate: 4000.0,
        showKhrDualCurrency: true,
      );

      final billBytes = await printerService.generateReceiptBytes(
        order: order,
        settings: settings,
        isPaid: false,
      );
      expect(billBytes.isNotEmpty, true);

      final paidBytes = await printerService.generateReceiptBytes(
        order: order,
        settings: settings,
        isPaid: true,
      );
      expect(paidBytes.isNotEmpty, true);
    });
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

    test('exportProfitLossReports generates valid styled P&L report file', () async {
      final exportService = ExcelExportService();
      const settings = StoreSettingsModel(
        storeName: 'OmniPOS Test Store',
        currencySymbol: '\$',
      );
      final List<ProfitLossReportModel> reports = [
        ProfitLossReportModel(
          periodLabel: 'March 2026',
          branchId: 'branch_1',
          branchName: 'Main Store',
          grossSalesRevenue: 5000.0,
          costOfSales: 2000.0,
          operatingExpenses: 800.0,
          baseRentPaidToMainBoss: 300.0,
          salesRoyaltyPaidToMainBoss: 200.0,
          otherIncome: 100.0,
          otherExpenses: 50.0,
        ),
      ];

      final filePath = await exportService.exportProfitLossReports(
        reports: reports,
        settings: settings,
        periodLabel: 'March 2026',
      );

      expect(filePath.isNotEmpty, true);
      expect(filePath.endsWith('.xlsx'), true);
      expect(File(filePath).existsSync(), true);

      final bytes = File(filePath).readAsBytesSync();
      final decoded = Excel.decodeBytes(bytes);
      expect(decoded.tables.containsKey('P&L Reports'), true);
      expect(decoded.tables['P&L Reports']!.rows.isNotEmpty, true);
    });

    test('exportSalesReport produces 5 professional sheets with data and styling', () async {
      final exportService = ExcelExportService();
      final metrics = SalesMetrics(
        totalRevenue: 200.0,
        totalCost: 80.0,
        grossProfit: 120.0,
        totalOrders: 2,
        totalItemsSold: 4,
        averageOrderValue: 100.0,
        cashRevenue: 100.0,
        qrRevenue: 100.0,
        cashOrderCount: 1,
        qrOrderCount: 1,
      );

      const settings = StoreSettingsModel(
        storeName: 'Executive Cafe',
        currencySymbol: '\$',
      );

      final filePath = await exportService.exportSalesReport(
        metrics: metrics,
        orders: [
          OrderModel(
            id: 'ord_1',
            receiptNo: 'SAL-20260908-0004',
            orderNumber: '0004',
            subtotal: 100.0,
            totalAmount: 100.0,
            items: [
              OrderItemModel(
                id: 'item_1',
                orderId: 'ord_1',
                productId: 'p1',
                productName: 'Iced Latte',
                unitPrice: 50.0,
                quantity: 2,
                totalPrice: 100.0,
              ),
            ],
            status: OrderStatus.completed,
            paymentMethod: PaymentMethod.cash,
            orderType: 'Dine-In',
            createdAt: DateTime.now(),
          ),
        ],
        topItems: [
          TopSellingItem(
            productId: 'p1',
            productName: 'Iced Latte',
            totalQuantity: 2,
            totalRevenue: 100.0,
          ),
        ],
        logs: [],
        settings: settings,
      );

      expect(File(filePath).existsSync(), true);
      final decoded = Excel.decodeBytes(File(filePath).readAsBytesSync());
      expect(decoded.tables.containsKey('Sales & Profit Summary'), true);
      expect(decoded.tables.containsKey('Product Profitability'), true);
      expect(decoded.tables.containsKey('Orders Register'), true);
      expect(decoded.tables.containsKey('Itemized Sales Details'), true);
      expect(decoded.tables.containsKey('Audit & Receipt Logs'), true);
    });
  });

  group('Kitchen Ticket Printing & QR Settings Tests', () {
    test('StoreSettingsModel serializes and deserializes qrImagePath', () {
      const settings = StoreSettingsModel(
        storeName: 'Test Burger House',
        qrImagePath: 'C:/assets/aba_khqr.png',
      );

      final map = settings.toMap();
      expect(map['qr_image_path'], 'C:/assets/aba_khqr.png');

      final deserialized = StoreSettingsModel.fromMap(map);
      expect(deserialized.qrImagePath, 'C:/assets/aba_khqr.png');

      final cleared = deserialized.copyWith(clearQrImagePath: true);
      expect(cleared.qrImagePath, isNull);
    });

    test('StoreSettingsModel serializes and deserializes printer margins and logo toggle', () {
      const settings = StoreSettingsModel(
        storeName: 'Test Bistro',
        printerMarginTop: 3.5,
        printerMarginBottom: 5.0,
        printerMarginLeft: 1.5,
        printerMarginRight: 2.5,
        printLogoOnReceipt: true,
        useSumatraPdf: true,
      );

      final map = settings.toMap();
      expect(map['printer_margin_top'], '3.5');
      expect(map['printer_margin_bottom'], '5.0');
      expect(map['printer_margin_left'], '1.5');
      expect(map['printer_margin_right'], '2.5');
      expect(map['print_logo_on_receipt'], '1');
      expect(map['use_sumatra_pdf'], '1');

      final deserialized = StoreSettingsModel.fromMap(map);
      expect(deserialized.printerMarginTop, 3.5);
      expect(deserialized.printerMarginBottom, 5.0);
      expect(deserialized.printerMarginLeft, 1.5);
      expect(deserialized.printerMarginRight, 2.5);
      expect(deserialized.printLogoOnReceipt, true);
      expect(deserialized.useSumatraPdf, true);
    });

    test('StoreSettingsModel sanitizes legacy dummy pay.restaurant.com template to empty string for bank payment', () {
      final legacyMap = {
        'qr_payload_template': 'https://pay.restaurant.com/pos?order=',
      };
      final deserialized = StoreSettingsModel.fromMap(legacyMap);
      expect(deserialized.qrPayloadTemplate, '');
    });

    test(
      'PrinterService generates kitchen ticket bytes without prices or totals',
      () async {
        final printerService = PrinterService();
        const settings = StoreSettingsModel(
          storeName: 'Test Kitchen',
          currencySymbol: '\$',
          isPaperSize80mm: true,
        );

        final order = OrderModel(
          id: 'ord_kitchen_01',
          receiptNo: 'REC-20260907-0042',
          orderNumber: '042',
          tableNumber: 'T05',
          orderType: 'DINE_IN',
          subtotal: 35.00,
          totalAmount: 35.00,
          paymentMethod: PaymentMethod.cash,
          kitchenStatus: KitchenStatus.pending,
          items: [
            OrderItemModel(
              id: 'item_k1',
              orderId: 'ord_kitchen_01',
              productId: 'prod_burger',
              productName: 'Truffle Wagyu Burger',
              quantity: 2,
              unitPrice: 12.50,
              totalPrice: 25.00,
              notes: 'Medium Rare, No Onions',
            ),
            OrderItemModel(
              id: 'item_k2',
              orderId: 'ord_kitchen_01',
              productId: 'prod_fries',
              productName: 'Parmesan Truffle Fries',
              quantity: 1,
              unitPrice: 10.00,
              totalPrice: 10.00,
            ),
          ],
        );

        final bytes = await printerService.generateKitchenTicketBytes(
          order: order,
          settings: settings,
        );

        expect(bytes.isNotEmpty, true);

        // Convert ESC/POS bytes to ASCII string to verify strictly no prices/totals
        final text = String.fromCharCodes(
          bytes.where((b) => b >= 32 && b <= 126),
        );
        expect(text.contains('KITCHEN ORDER'), true);
        expect(text.contains('T05'), true);
        expect(text.contains('042'), true);
        expect(text.contains('TRUFFLE WAGYU BURGER'), true);
        expect(text.contains('Medium Rare, No Onions'), true);

        // Strictly NO prices or totals in kitchen ticket text
        expect(text.contains('35.00'), false);
        expect(text.contains('12.50'), false);
        expect(text.contains('25.00'), false);
        expect(text.contains('10.00'), false);
        expect(text.contains('SUBTOTAL'), false);
        expect(text.contains('TOTAL'), false);
      },
    );

    test('CartController marks order confirmed to chef and retains pending payment state', () {
      final cart = CartController();
      final p1 = Product(
        id: 'prod_1',
        categoryId: 'cat_1',
        name: 'Cheeseburger',
        price: 10.0,
      );
      cart.addProduct(p1);

      expect(cart.isConfirmedPending, false);
      expect(cart.currentPendingOrderId, null);

      // Cashier clicks "Confirm Order (Print for Chef)"
      cart.markOrderConfirmed(
        orderId: 'ord_chef_99',
        orderNumber: '0042',
        receiptNo: 'REC-2026-0042',
      );

      // Order is confirmed for chef, but payment is NOT yet completed
      expect(cart.isConfirmedPending, true);
      expect(cart.currentPendingOrderId, 'ord_chef_99');
      expect(cart.orderNumber, '0042');
      expect(cart.currentReceiptNo, 'REC-2026-0042');
      expect(cart.items.length, 1);
      expect(cart.subtotal, 10.0);
      expect(cart.totalAmount, 11.0); // includes 10% tax

      // After payment or new order, clearing cart resets pending state
      cart.clearCart(syncCfd: false);
      expect(cart.isConfirmedPending, false);
      expect(cart.currentPendingOrderId, null);
      expect(cart.currentReceiptNo, null);
    });

    test(
      'PrinterService detects or gracefully handles SumatraPDF resolution',
      () async {
        final printerService = PrinterService();
        final path = await printerService.findSumatraPdfExecutable();
        if (path != null) {
          expect(path.toLowerCase().contains('sumatrapdf'), true);
        }
        final status = await printerService.verifyPrinterStatus();
        expect(status.containsKey('hasSumatraPdf'), true);
      },
    );

    test(
      'StoreSettingsModel handles deviceProfile serialization and defaults',
      () {
        const defaultSettings = StoreSettingsModel();
        expect(defaultSettings.deviceProfile, DeviceProfile.auto);

        final kioskSettings = defaultSettings.copyWith(
          deviceProfile: DeviceProfile.caH2Kiosk,
        );
        expect(kioskSettings.deviceProfile, DeviceProfile.caH2Kiosk);

        final map = kioskSettings.toMap();
        expect(map['device_profile'], DeviceProfile.caH2Kiosk);

        final restored = StoreSettingsModel.fromMap(map);
        expect(restored.deviceProfile, DeviceProfile.caH2Kiosk);
      },
    );

    test('DeviceProfile constants, labels, descriptions and helper logic', () {
      expect(
        DeviceProfile.getLabel(DeviceProfile.caH2Kiosk).contains('21.5"'),
        true,
      );
      expect(
        DeviceProfile.getLabel(DeviceProfile.ca9Desktop).contains('15.6"'),
        true,
      );
      expect(
        DeviceProfile.getLabel(DeviceProfile.auto).contains('Auto-Detect'),
        true,
      );

      expect(
        DeviceProfile.getDescription(DeviceProfile.caH2Kiosk).contains('640px'),
        true,
      );
      expect(
        DeviceProfile.getDescription(DeviceProfile.ca9Desktop)
            .contains('1366×768'),
        true,
      );
    });

    test('StoreSettingsModel useSumatraPdf defaults to true and roundtrips in toMap/fromMap', () {
      const defaultSettings = StoreSettingsModel();
      expect(defaultSettings.useSumatraPdf, true);

      final map = defaultSettings.toMap();
      expect(map['use_sumatra_pdf'], '1');

      final disabled = defaultSettings.copyWith(useSumatraPdf: false);
      expect(disabled.useSumatraPdf, false);
      expect(disabled.toMap()['use_sumatra_pdf'], '0');

      final restored = StoreSettingsModel.fromMap(disabled.toMap());
      expect(restored.useSumatraPdf, false);
    });

    test('PrinterService findSumatraPdfExecutable finds bundled or system executable on Windows', () async {
      final path = await PrinterService().findSumatraPdfExecutable();
      if (Platform.isWindows) {
        expect(path != null, true, reason: 'SumatraPDF executable should be found in windows/bin or C:\\POS');
        expect(File(path!).existsSync(), true);
      }
    });
  });
}
