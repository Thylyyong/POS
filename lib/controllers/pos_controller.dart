import 'dart:async';

import 'package:flutter/material.dart';

import '../core/async_guard.dart';
import '../core/debouncer.dart';
import '../database/order_dao.dart';
import '../database/product_dao.dart';
import '../database/table_dao.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/store_settings_model.dart';
import '../services/barcode_service.dart';
import '../services/pdf_receipt_service.dart';
import '../services/presentation_service.dart';
import '../services/printer_service.dart';
import '../services/receipt_file_service.dart';
import 'cart_controller.dart';
import 'table_controller.dart';

class PosController extends ChangeNotifier {
  final ProductDao _productDao = ProductDao();
  final OrderDao _orderDao = OrderDao();
  final TableDao _tableDao = TableDao();
  final PrinterService _printerService = PrinterService();
  final PresentationService _presentationService = PresentationService();
  final BarcodeService _barcodeService = BarcodeService();
  final ReceiptFileService _receiptFileService = ReceiptFileService();
  final PdfReceiptService _pdfReceiptService = PdfReceiptService();

  // ── Utilities ─────────────────────────────────────────────────────────────
  final _productGuard = AsyncGuard();
  final _searchDebouncer = Debouncer(
    duration: const Duration(milliseconds: 300),
  );

  // ── State ─────────────────────────────────────────────────────────────────
  List<Category> _categories = [];
  List<Category> get categories => _categories;

  List<Subcategory> _subcategories = [];
  List<Subcategory> get subcategories => _subcategories;

  List<Product> _products = [];
  List<Product> get products => _products;

  String _selectedCategoryId = 'ALL';
  String get selectedCategoryId => _selectedCategoryId;

  String? _selectedSubcategoryId;
  String? get selectedSubcategoryId => _selectedSubcategoryId;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  OrderModel? _lastCompletedOrder;
  OrderModel? get lastCompletedOrder => _lastCompletedOrder;

  /// File paths of the most recently saved receipt (app docs + downloads).
  ReceiptSaveResult? _lastReceiptSaveResult;
  ReceiptSaveResult? get lastReceiptSaveResult => _lastReceiptSaveResult;

  String? _scannedBarcodeNotice;
  String? get scannedBarcodeNotice => _scannedBarcodeNotice;

  // Tracked timers
  Timer? _noticeTimer;
  Timer? _cfdIdleTimer;

  // ── Init ──────────────────────────────────────────────────────────────────
  PosController() {
    _init();
  }

  Future<void> _init() async {
    _setLoading(true);
    try {
      await _loadCategoriesInternal();
      await _loadProductsInternal();
      _initBarcodeListener();
    } catch (e) {
      _setError('Failed to initialise POS: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ── Barcode listener ──────────────────────────────────────────────────────
  void _initBarcodeListener() {
    _barcodeService.startListening((barcode) async {
      final product = await _productDao.getProductByBarcode(barcode);
      final notice = product != null
          ? 'Scanned: ${product.name}'
          : 'Unknown SKU: $barcode';

      _scannedBarcodeNotice = notice;
      notifyListeners();

      _noticeTimer?.cancel();
      _noticeTimer = Timer(const Duration(milliseconds: 2500), () {
        _scannedBarcodeNotice = null;
        notifyListeners();
      });
    });
  }

  // ── Categories ────────────────────────────────────────────────────────────
  Future<void> loadCategories() async {
    try {
      await _loadCategoriesInternal();
    } catch (e) {
      _setError('Failed to load categories: $e');
    }
  }

  Future<void> _loadCategoriesInternal() async {
    _categories = await _productDao.getAllCategories();
    _subcategories = await _productDao.getAllSubcategories();
    notifyListeners();
  }

  // ── Products ──────────────────────────────────────────────────────────────
  Future<void> loadProducts() async {
    _setLoading(true);
    try {
      await _loadProductsInternal();
    } catch (e) {
      _setError('Failed to load products: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadProductsInternal() async {
    final token = _productGuard.start();

    final List<Product> result;
    if (_searchQuery.isNotEmpty) {
      result = await _productDao.searchProducts(
        _searchQuery,
        categoryId: _selectedCategoryId == 'ALL' ? null : _selectedCategoryId,
      );
    } else if (_selectedCategoryId == 'ALL') {
      result = await _productDao.getAllProducts();
    } else {
      var list = await _productDao.getProductsByCategory(_selectedCategoryId);
      if (_selectedSubcategoryId != null) {
        list = list
            .where((p) => p.subcategoryId == _selectedSubcategoryId)
            .toList();
      }
      result = list;
    }

    if (_productGuard.isStale(token)) return;

    _products = result;
    notifyListeners();
  }

  // ── Selection ─────────────────────────────────────────────────────────────
  void selectCategory(String categoryId) {
    _selectedCategoryId = categoryId;
    _selectedSubcategoryId = null;
    loadProducts();
  }

  void selectSubcategory(String? subcategoryId) {
    _selectedSubcategoryId = subcategoryId;
    loadProducts();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _searchDebouncer.call(loadProducts);
  }

  void clearSearch() {
    _searchQuery = '';
    _searchDebouncer.cancel();
    loadProducts();
  }

  // ── Barcode auto-add ──────────────────────────────────────────────────────
  Future<bool> handleBarcodeAutoAdd(String barcode, CartController cart) async {
    try {
      final product = await _productDao.getProductByBarcode(barcode);
      if (product != null) {
        cart.addProduct(product);
        return true;
      }
    } catch (e) {
      _setError('Barcode lookup failed: $e');
    }
    return false;
  }

  // ── Load Pending Order into Cart ──────────────────────────────────────────
  void loadPendingOrderIntoCart(OrderModel order, CartController cart) {
    cart.loadExistingOrder(order: order, allProducts: _products);
  }

  // ── Merge Pending Order with Current Cart (For Add More Items / Merge) ────
  void mergePendingOrderWithCart(OrderModel order, CartController cart) {
    cart.mergeWithExistingOrder(order: order, allProducts: _products);
  }

  // ── Customer Display ──────────────────────────────────────────────────────
  void showPaymentOnCustomerDisplay({
    required CartController cart,
    required String qrPayload,
  }) {
    final payload = PresentationPayload(
      state: CfdScreenState.paymentQr,
      items: cart.items.map((i) => i.toPresentationMap()).toList(),
      subtotal: cart.subtotal,
      discountAmount: cart.discountAmount,
      taxAmount: cart.taxAmount,
      totalAmount: cart.totalAmount,
      currencySymbol: cart.currencySymbol,
      qrData: qrPayload,
    );
    _presentationService.sendToCustomerDisplay(payload);
  }

  void syncCartWithCustomerDisplay(CartController cart) {
    final payload = PresentationPayload(
      state: cart.isEmpty ? CfdScreenState.idle : CfdScreenState.cartActive,
      items: cart.items.map((i) => i.toPresentationMap()).toList(),
      subtotal: cart.subtotal,
      discountAmount: cart.discountAmount,
      taxAmount: cart.taxAmount,
      totalAmount: cart.totalAmount,
      currencySymbol: cart.currencySymbol,
    );
    _presentationService.sendToCustomerDisplay(payload);
  }

  // ── Save Order as PENDING (Hold for Table / Dine-in) ───────────────────────
  Future<OrderModel?> saveOrderAsPending({
    required CartController cart,
    required StoreSettingsModel settings,
    String branchId = 'store_a',
    TableController? tableController,
  }) async {
    if (cart.items.isEmpty) return null;

    try {
      final orderId =
          cart.currentPendingOrderId ??
          'ord_${DateTime.now().millisecondsSinceEpoch}';
      final receiptNo = await _orderDao.generateNextReceiptNumber();
      final dailyOrderNo =
          cart.orderNumber ?? await _orderDao.generateNextDailyOrderNumber();
      final totalAmount = cart.totalAmount;

      final order = OrderModel(
        id: orderId,
        branchId: branchId,
        receiptNo: receiptNo,
        orderNumber: dailyOrderNo,
        tableId: cart.tableId,
        tableNumber:
            cart.tableNumber ??
            (cart.orderType == 'TAKEAWAY' ? 'Takeaway' : 'T01'),
        customerName: cart.customerName ?? 'Guest',
        orderType: cart.orderType,
        subtotal: cart.subtotal,
        discountAmount: cart.discountAmount,
        discountPercent: cart.discountPercent,
        taxAmount: cart.taxAmount,
        taxRate: cart.taxRate,
        totalAmount: totalAmount,
        paymentMethod: PaymentMethod.cash,
        cashTendered: 0.0,
        changeAmount: 0.0,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
      );

      final items = cart.items.map((i) => i.toOrderItem(orderId)).toList();

      final savedOrder = await _orderDao.savePendingOrder(
        order: order,
        items: items,
      );

      _lastCompletedOrder = savedOrder;

      // Auto-save markdown receipt for kitchen / records
      final saveResult = await _receiptFileService.saveReceiptMarkdown(
        order: savedOrder,
        settings: settings,
      );
      _lastReceiptSaveResult = saveResult;

      // Reload table states across app
      if (tableController != null) {
        await tableController.loadTables();
      }

      // Clear cart
      cart.clearCart();
      notifyListeners();

      return savedOrder;
    } catch (e) {
      _setError('Failed to save pending order: $e');
      return null;
    }
  }

  // ── Complete Checkout & Payment ───────────────────────────────────────────
  Future<OrderModel?> processCheckout({
    required CartController cart,
    required StoreSettingsModel settings,
    required PaymentMethod paymentMethod,
    String branchId = 'store_a',
    double cashTendered = 0.0,
    TableController? tableController,
  }) async {
    if (cart.items.isEmpty) return null;

    _cfdIdleTimer?.cancel();

    try {
      final isExistingPending = cart.currentPendingOrderId != null;
      final orderId =
          cart.currentPendingOrderId ??
          'ord_${DateTime.now().millisecondsSinceEpoch}';
      final receiptNo = await _orderDao.generateNextReceiptNumber();
      final dailyOrderNo =
          cart.orderNumber ?? await _orderDao.generateNextDailyOrderNumber();
      final totalAmount = cart.totalAmount;
      final changeAmount = paymentMethod == PaymentMethod.cash
          ? (cashTendered - totalAmount).clamp(0.0, double.infinity)
          : 0.0;

      final order = OrderModel(
        id: orderId,
        branchId: branchId,
        receiptNo: receiptNo,
        orderNumber: dailyOrderNo,
        tableId: cart.tableId,
        tableNumber:
            cart.tableNumber ??
            (cart.orderType == 'TAKEAWAY' ? 'Takeaway' : 'T01'),
        customerName: cart.customerName ?? 'Guest',
        orderType: cart.orderType,
        subtotal: cart.subtotal,
        discountAmount: cart.discountAmount,
        discountPercent: cart.discountPercent,
        taxAmount: cart.taxAmount,
        taxRate: cart.taxRate,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        cashTendered: paymentMethod == PaymentMethod.cash
            ? cashTendered
            : totalAmount,
        changeAmount: changeAmount,
        status: OrderStatus.completed,
        createdAt: DateTime.now(),
      );

      final items = cart.items.map((i) => i.toOrderItem(orderId)).toList();

      // Save order and free table if assigned
      final savedOrder = await _orderDao.saveOrderTransaction(
        order: order,
        items: items,
        action: isExistingPending ? 'PENDING_ORDER_PAID' : 'INITIAL_PRINT',
      );

      if (cart.tableId != null) {
        await _tableDao.freeTable(cart.tableId!);
      }

      // Reload tables across app
      if (tableController != null) {
        await tableController.loadTables();
      }

      _lastCompletedOrder = savedOrder;

      // 2a. Auto-save receipt as Markdown file to app docs + Downloads
      final saveResult = await _receiptFileService.saveReceiptMarkdown(
        order: savedOrder,
        settings: settings,
      );
      _lastReceiptSaveResult = saveResult;

      // 2b. Auto-save receipt as PDF file to app docs + Downloads
      final pdfResult = await _pdfReceiptService.saveReceiptPdf(
        order: savedOrder,
        settings: settings,
      );

      final loggedPath = pdfResult.appDocPath.isNotEmpty
          ? pdfResult.appDocPath
          : (pdfResult.downloadsPath ?? saveResult.appDocPath);

      if (loggedPath.isNotEmpty) {
        await _orderDao.logReceiptAction(
          receiptNo: savedOrder.receiptNo,
          orderId: savedOrder.id,
          action: 'PDF_SAVED',
          isSuccess: true,
          receiptFilePath: loggedPath,
        );
      }

      // 2. Hardware: kick cash drawer / print receipt
      if (settings.autoPrintOnPayment) {
        await _printerService.printReceipt(
          order: savedOrder,
          settings: settings,
          isReprint: false,
        );
      } else if (settings.autoKickCashDrawer &&
          paymentMethod == PaymentMethod.cash) {
        await _printerService.kickCashDrawer();
      }

      // 3. Update CFD with Payment Success state
      final cfdPayload = PresentationPayload(
        state: CfdScreenState.paymentSuccess,
        items: items
            .map(
              (i) => {
                'productId': i.productId,
                'productName': i.productName,
                'quantity': i.quantity,
                'unitPrice': i.unitPrice,
                'totalPrice': i.totalPrice,
              },
            )
            .toList(),
        subtotal: savedOrder.subtotal,
        discountAmount: savedOrder.discountAmount,
        taxAmount: savedOrder.taxAmount,
        totalAmount: savedOrder.totalAmount,
        currencySymbol: settings.currencySymbol,
        receiptNo: savedOrder.receiptNo,
        cashTendered: savedOrder.cashTendered,
        changeAmount: savedOrder.changeAmount,
        thankYouNote: settings.footerNote,
      );
      await _presentationService.sendToCustomerDisplay(cfdPayload);

      // 4. Clear cart without resetting CFD paymentSuccess screen
      cart.clearCart(syncCfd: false);
      notifyListeners();

      // 5. Return CFD smoothly to idle after 6s (only if cart is still empty)
      _cfdIdleTimer?.cancel();
      _cfdIdleTimer = Timer(const Duration(seconds: 6), () {
        if (cart.isEmpty) {
          _presentationService.sendToCustomerDisplay(
            PresentationPayload(
              state: CfdScreenState.idle,
              currencySymbol: settings.currencySymbol,
            ),
          );
        }
      });

      return savedOrder;
    } catch (e) {
      _setError('Checkout failed: $e');
      return null;
    }
  }

  // ── Reprint ───────────────────────────────────────────────────────────────
  Future<bool> reprintReceipt({
    required OrderModel order,
    required StoreSettingsModel settings,
  }) async {
    try {
      final success = await _printerService.printReceipt(
        order: order,
        settings: settings,
        isReprint: true,
      );

      final saveResult = await _receiptFileService.saveReceiptMarkdown(
        order: order,
        settings: settings,
        isReprint: true,
      );

      await _orderDao.logReceiptAction(
        receiptNo: order.receiptNo,
        orderId: order.id,
        action: 'REPRINT',
        isSuccess: success,
        receiptFilePath: saveResult.appDocPath.isNotEmpty
            ? saveResult.appDocPath
            : null,
      );
      return success;
    } catch (e) {
      _setError('Reprint failed: $e');
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    debugPrint('[PosController] $message');
    _error = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _barcodeService.stopListening();
    _noticeTimer?.cancel();
    _cfdIdleTimer?.cancel();
    _searchDebouncer.cancel();
    _productGuard.reset();
    super.dispose();
  }
}
