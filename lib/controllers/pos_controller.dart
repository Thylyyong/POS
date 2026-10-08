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

  double _scrollOffset = 0.0;
  double get scrollOffset => _scrollOffset;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isCheckoutInProgress = false;

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
  Timer? _scrollDebounceTimer;

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
    _syncMenuToCfd();
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
    _syncMenuToCfd();
  }

  int _menuVersion = 0;
  int get menuVersion => _menuVersion;

  Future<void> _syncMenuToCfd() async {
    try {
      final allProducts = await _productDao.getAllProducts();
      await _presentationService.sendMenuToCustomerDisplay(
        categories: _categories.map((c) => c.toMap()).toList(),
        subcategories: _subcategories.map((s) => s.toMap()).toList(),
        products: allProducts.map((p) => p.toMap()).toList(),
      );
      await _presentationService.syncPosNavigation(
        selectedCategoryId: _selectedCategoryId,
        selectedSubcategoryId: _selectedSubcategoryId,
        searchQuery: _searchQuery,
        scrollOffset: _scrollOffset,
        menuVersion: _menuVersion,
      );
    } catch (_) {}
  }

  /// Explicitly broadcast menu changes (including new/edited product images) to CDS
  Future<void> broadcastMenuUpdate() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _menuVersion++;
    await _syncMenuToCfd();
    notifyListeners();
  }

  // ── Selection & Live CFD Synchronization ──────────────────────────────────
  void selectCategory(String categoryId, {bool broadcast = true}) {
    _selectedCategoryId = categoryId;
    _selectedSubcategoryId = null;
    _scrollOffset = 0.0;
    loadProducts();
    if (broadcast) {
      _presentationService.syncPosNavigation(
        selectedCategoryId: categoryId,
        clearSubcategory: true,
        scrollOffset: 0.0,
      );
    }
  }

  void selectSubcategory(String? subcategoryId, {bool broadcast = true}) {
    _selectedSubcategoryId = subcategoryId;
    _scrollOffset = 0.0;
    loadProducts();
    if (broadcast) {
      _presentationService.syncPosNavigation(
        selectedSubcategoryId: subcategoryId,
        scrollOffset: 0.0,
      );
    }
  }

  void setSearchQuery(String query, {bool broadcast = true}) {
    _searchQuery = query;
    _searchDebouncer.call(loadProducts);
    if (broadcast) {
      _presentationService.syncPosNavigation(
        searchQuery: query,
        scrollOffset: 0.0,
      );
    }
  }

  void clearSearch({bool broadcast = true}) {
    _searchQuery = '';
    _searchDebouncer.cancel();
    loadProducts();
    if (broadcast) {
      _presentationService.syncPosNavigation(
        searchQuery: '',
        scrollOffset: 0.0,
      );
    }
  }

  void setScrollOffset(double offset, {bool broadcast = true}) {
    if ((_scrollOffset - offset).abs() < 1.0) return;
    _scrollOffset = offset;
    notifyListeners();

    if (broadcast) {
      _scrollDebounceTimer?.cancel();
      _scrollDebounceTimer = Timer(const Duration(milliseconds: 40), () {
        _presentationService.syncPosNavigation(scrollOffset: offset);
      });
    }
  }

  // ── Barcode auto-add ──────────────────────────────────────────────────────
  Future<bool> handleBarcodeAutoAdd(String barcode, CartController cart, {bool isRegisterOpen = true}) async {
    if (!isRegisterOpen) return false;
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
    String? qrImagePath,
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
      qrImagePath: qrImagePath,
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
    bool clearCartAfter = false,
    bool printBill = false,
    bool showQr = true,
    String? cashierId,
    String? cashierName,
  }) async {
    if (cart.items.isEmpty || _isCheckoutInProgress) return null;
    if (!cart.totalAmount.isFinite || cart.totalAmount < 0) {
      _setError('Order total is invalid. Review the cart before checkout.');
      return null;
    }
    _isCheckoutInProgress = true;

    try {
      final orderId =
          cart.currentPendingOrderId ??
          'ord_${DateTime.now().millisecondsSinceEpoch}';
      final receiptNo =
          cart.currentReceiptNo ?? await _orderDao.generateNextReceiptNumber();
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
        kitchenStatus: KitchenStatus.pending,
        cashierId: cashierId,
        cashierName: cashierName,
        createdAt: DateTime.now(),
      );

      final items = cart.items.map((i) => i.toOrderItem(orderId)).toList();

      final savedOrder = await _orderDao.savePendingOrder(
        order: order,
        items: items,
      );

      _lastCompletedOrder = savedOrder;

      // Auto-save markdown receipt for records
      final saveResult = await _receiptFileService.saveReceiptMarkdown(
        order: savedOrder,
        settings: settings,
      );
      _lastReceiptSaveResult = saveResult;

      // Print unpaid bill with or without KHQR for customer to review & pay
      if (printBill) {
        _printerService
            .printReceipt(
              order: savedOrder,
              settings: settings,
              isPaid: false,
              showQr: showQr,
              allowSystemDialog: false,
            )
            .catchError((_) => false);
      }

      // Reload table states across app
      if (tableController != null) {
        await tableController.loadTables();
      }

      // Update cart state: either clear or retain as confirmed pending
      if (clearCartAfter) {
        cart.clearCart();
      } else {
        cart.markOrderConfirmed(
          orderId: savedOrder.id,
          orderNumber: savedOrder.orderNumber,
          receiptNo: savedOrder.receiptNo,
        );
      }
      notifyListeners();

      return savedOrder;
    } catch (e) {
      _setError('Failed to save pending order: $e');
      return null;
    }
  }

  // ── Print Unpaid Bill (Saves Order as Pending & Prints Bill with KHQR) ─────
  Future<OrderModel?> printUnpaidBill({
    required CartController cart,
    required StoreSettingsModel settings,
    String branchId = 'store_a',
    TableController? tableController,
    bool clearCartAfter = false,
    bool showQr = true,
    String? cashierId,
    String? cashierName,
  }) async {
    return await saveOrderAsPending(
      cart: cart,
      settings: settings,
      branchId: branchId,
      tableController: tableController,
      clearCartAfter: clearCartAfter,
      printBill: true,
      showQr: showQr,
      cashierId: cashierId,
      cashierName: cashierName,
    );
  }

  // Backwards-compatible alias for existing code
  Future<OrderModel?> confirmOrderToKitchen({
    required CartController cart,
    required StoreSettingsModel settings,
    String branchId = 'store_a',
    TableController? tableController,
    bool clearCartAfter = false,
  }) async {
    return await printUnpaidBill(
      cart: cart,
      settings: settings,
      branchId: branchId,
      tableController: tableController,
      clearCartAfter: clearCartAfter,
    );
  }

  // ── Complete Checkout & Payment ───────────────────────────────────────────
  Future<OrderModel?> processCheckout({
    required CartController cart,
    required StoreSettingsModel settings,
    required PaymentMethod paymentMethod,
    String branchId = 'store_a',
    double cashTendered = 0.0,
    TableController? tableController,
    String userId = 'usr_cashier',
    String userName = 'Staff Cashier',
    String userRole = 'CASHIER',
  }) async {
    if (cart.items.isEmpty) return null;

    _cfdIdleTimer?.cancel();
    OrderModel? committedOrder;

    try {
      final isExistingPending = cart.currentPendingOrderId != null;
      final orderId =
          cart.currentPendingOrderId ??
          'ord_${DateTime.now().millisecondsSinceEpoch}';
      final receiptNo =
          cart.currentReceiptNo ?? await _orderDao.generateNextReceiptNumber();
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
        cashierId: userId,
        cashierName: userName,
        createdAt: DateTime.now(),
      );

      final items = cart.items.map((i) => i.toOrderItem(orderId)).toList();

      // Save order and free table if assigned
      final savedOrder = await _orderDao.saveOrderTransaction(
        order: order,
        items: items,
        action: isExistingPending ? 'PENDING_ORDER_PAID' : 'INITIAL_PRINT',
        beforeCommit: (txn) => _productDao.deductStockForOrderItems(
          items: items,
          orderId: orderId,
          receiptNo: receiptNo,
          userId: userId,
          userName: userName,
          userRole: userRole,
          transaction: txn,
        ),
      );
      committedOrder = savedOrder;

      // Refresh the inventory view after the sale and its stock audit commit.
      await loadProducts();

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

      // 2b. Auto-save receipt as PDF to device background storage (non-blocking)
      _pdfReceiptService
          .saveReceiptPdf(
            order: savedOrder,
            settings: settings,
          )
          .then((pdfResult) async {
            final loggedPath = pdfResult.downloadsPath ?? pdfResult.appDocPath;
            if (loggedPath.isNotEmpty) {
              await _orderDao.logReceiptAction(
                receiptNo: savedOrder.receiptNo,
                orderId: savedOrder.id,
                action: 'PDF_SAVED',
                isSuccess: true,
                receiptFilePath: loggedPath,
              );
            }
          })
          .catchError((_) {});

      // 2. Hardware: kick cash drawer / print paid receipt
      if (settings.autoPrintOnPayment) {
        _printerService
            .printReceipt(
              order: savedOrder,
              settings: settings,
              isPaid: true,
              isReprint: false,
              allowSystemDialog: false,
            )
            .catchError((_) => false);
      } else if (settings.autoKickCashDrawer &&
          paymentMethod == PaymentMethod.cash) {
        _printerService.kickCashDrawer().catchError((_) => <int>[]);
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
      if (committedOrder != null) {
        // The sale is already durable. Later receipt, printer, or display
        // failures must not make checkout look unpaid and invite a duplicate.
        cart.clearCart(syncCfd: false);
        _lastCompletedOrder = committedOrder;
        return committedOrder;
      }
      _setError('Checkout failed: $e');
      return null;
    } finally {
      _isCheckoutInProgress = false;
    }
  }

  // ── Reprint ───────────────────────────────────────────────────────────────
  Future<bool> reprintReceipt({
    required OrderModel order,
    required StoreSettingsModel settings,
    bool isPaid = true,
    bool showQr = true,
  }) async {
    try {
      final success = await _printerService.printReceipt(
        order: order,
        settings: settings,
        isPaid: isPaid,
        showQr: showQr,
        isReprint: true,
        allowSystemDialog: false,
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
    _scrollDebounceTimer?.cancel();
    _searchDebouncer.cancel();
    _productGuard.reset();
    super.dispose();
  }
}
