import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../services/presentation_service.dart';

// ============================================================================
// CartItem — immutable value object; mutations go through CartController
// ============================================================================
class CartItem {
  final Product product;
  final int quantity;
  final String? notes;

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.notes,
  });

  CartItem copyWith({int? quantity, String? notes}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
    );
  }

  double get unitPrice => product.price;
  double get totalPrice => unitPrice * quantity;

  OrderItemModel toOrderItem(String orderId) {
    return OrderItemModel(
      id: 'item_${DateTime.now().microsecondsSinceEpoch}_${product.id}',
      orderId: orderId,
      productId: product.id,
      productName: product.name,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      notes: notes,
    );
  }

  Map<String, dynamic> toPresentationMap() => {
        'productId': product.id,
        'productName': product.name,
        'imagePath': product.imagePath,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
        'notes': notes,
      };
}

// ============================================================================
// CartController
// ============================================================================
class CartController extends ChangeNotifier {
  final PresentationService _presentationService = PresentationService();

  final List<CartItem> _items = [];
  List<CartItem> get items => List.unmodifiable(_items);

  // Table & Customer Context
  String? _tableId;
  String? get tableId => _tableId;

  String? _tableNumber;
  String? get tableNumber => _tableNumber;

  String? _customerName;
  String? get customerName => _customerName;

  String _orderType = 'DINE_IN'; // 'DINE_IN', 'TAKEAWAY', 'DELIVERY'
  String get orderType => _orderType;

  String? _currentPendingOrderId;
  String? get currentPendingOrderId => _currentPendingOrderId;

  String? _orderNumber; // e.g. "001", "002"
  String? get orderNumber => _orderNumber;

  // Held Carts (multi-table / suspended transactions)
  final List<List<CartItem>> _heldCarts = [];
  List<List<CartItem>> get heldCarts => List.unmodifiable(_heldCarts);

  double _discountPercent = 0.0;
  double get discountPercent => _discountPercent;

  double _discountFixed = 0.0;
  double get discountFixed => _discountFixed;

  double _taxRate = 10.0;
  double get taxRate => _taxRate;

  String _currencySymbol = '\$';
  String get currencySymbol => _currencySymbol;

  // ── Derived getters ──────────────────────────────────────────────────────

  int get totalItemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => _items.isEmpty;

  double get subtotal => _items.fold(0.0, (sum, i) => sum + i.totalPrice);

  double get discountAmount {
    if (_discountPercent > 0) return subtotal * (_discountPercent / 100.0);
    return _discountFixed > subtotal ? subtotal : _discountFixed;
  }

  double get subtotalAfterDiscount {
    final v = subtotal - discountAmount;
    return v > 0 ? v : 0.0;
  }

  double get taxAmount {
    if (_taxRate <= 0) return 0.0;
    return subtotalAfterDiscount * (_taxRate / 100.0);
  }

  double get totalAmount => subtotalAfterDiscount + taxAmount;

  // ── Table & Customer Management ──────────────────────────────────────────

  void setTableInfo({
    String? tableId,
    String? tableNumber,
    String? customerName,
    String orderType = 'DINE_IN',
  }) {
    _tableId = tableId;
    _tableNumber = tableNumber;
    if (customerName != null && customerName.trim().isNotEmpty) {
      _customerName = customerName.trim();
    }
    _orderType = orderType;
    notifyListeners();
  }

  void setCustomerName(String name) {
    _customerName = name.trim().isEmpty ? null : name.trim();
    notifyListeners();
  }

  void setOrderType(String type) {
    _orderType = type;
    if (type == 'TAKEAWAY') {
      _tableId = null;
      _tableNumber = 'Takeaway';
    }
    notifyListeners();
  }

  void clearTableInfo() {
    _tableId = null;
    _tableNumber = null;
    _customerName = null;
    _orderType = 'DINE_IN';
    _currentPendingOrderId = null;
    _orderNumber = null;
    notifyListeners();
  }

  // ── Load Existing Order ──────────────────────────────────────────────────

  void loadExistingOrder({
    required OrderModel order,
    required List<Product> allProducts,
  }) {
    _items.clear();
    _currentPendingOrderId = order.id;
    _tableId = order.tableId;
    _tableNumber = order.tableNumber;
    _customerName = order.customerName;
    _orderType = order.orderType;
    _orderNumber = order.orderNumber;
    _discountPercent = order.discountPercent;
    _discountFixed = order.discountAmount > 0 && order.discountPercent == 0 ? order.discountAmount : 0.0;

    for (var item in order.items) {
      final matchedProduct = allProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(
          id: item.productId,
          categoryId: 'unknown',
          name: item.productName,
          price: item.unitPrice,
        ),
      );
      _items.add(CartItem(
        product: matchedProduct,
        quantity: item.quantity,
        notes: item.notes,
      ));
    }
    _commit();
  }

  // ── Merge Existing Order with Current Cart (For Add More Items) ────────────
  void mergeWithExistingOrder({
    required OrderModel order,
    required List<Product> allProducts,
  }) {
    _currentPendingOrderId = order.id;
    _tableId = order.tableId;
    _tableNumber = order.tableNumber;
    if (_customerName == null || _customerName!.isEmpty) {
      _customerName = order.customerName;
    }
    _orderType = order.orderType;
    _orderNumber = order.orderNumber;
    if (order.discountPercent > 0) _discountPercent = order.discountPercent;
    if (order.discountAmount > 0 && order.discountPercent == 0) _discountFixed = order.discountAmount;

    // Merge existing items from DB into cart (combining quantities if same item)
    for (var item in order.items) {
      final matchedProduct = allProducts.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(
          id: item.productId,
          categoryId: 'unknown',
          name: item.productName,
          price: item.unitPrice,
        ),
      );
      
      final existingIndex = _items.indexWhere(
        (i) => i.product.id == matchedProduct.id && i.notes == item.notes,
      );
      if (existingIndex >= 0) {
        _items[existingIndex] = _items[existingIndex].copyWith(
          quantity: _items[existingIndex].quantity + item.quantity,
        );
      } else {
        _items.insert(
          0,
          CartItem(
            product: matchedProduct,
            quantity: item.quantity,
            notes: item.notes,
          ),
        );
      }
    }
    _commit();
  }

  // ── Config ───────────────────────────────────────────────────────────────

  void updateConfig({required double taxRate, required String currencySymbol}) {
    _taxRate = taxRate;
    _currencySymbol = currencySymbol;
    _commit();
  }

  // ── Cart mutations ───────────────────────────────────────────────────────

  void addProduct(Product product, {int quantity = 1, String? notes}) {
    final idx = _items.indexWhere(
      (i) => i.product.id == product.id && i.notes == notes,
    );
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity + quantity);
    } else {
      _items.add(CartItem(product: product, quantity: quantity, notes: notes));
    }
    _commit();
  }

  void incrementQuantity(int index) {
    if (_validIndex(index)) {
      _items[index] = _items[index].copyWith(quantity: _items[index].quantity + 1);
      _commit();
    }
  }

  void decrementQuantity(int index) {
    if (_validIndex(index)) {
      if (_items[index].quantity > 1) {
        _items[index] = _items[index].copyWith(quantity: _items[index].quantity - 1);
      } else {
        _items.removeAt(index);
      }
      _commit();
    }
  }

  void removeItem(int index) {
    if (_validIndex(index)) {
      _items.removeAt(index);
      _commit();
    }
  }

  void updateItemNotes(int index, String? notes) {
    if (_validIndex(index)) {
      _items[index] = _items[index].copyWith(notes: notes);
      notifyListeners();
    }
  }

  // ── Discount ─────────────────────────────────────────────────────────────

  void setDiscountPercent(double percent) {
    _discountPercent = percent.clamp(0.0, 100.0);
    _discountFixed = 0.0;
    _commit();
  }

  void setDiscountFixed(double amount) {
    _discountFixed = amount < 0 ? 0.0 : amount;
    _discountPercent = 0.0;
    _commit();
  }

  void clearDiscount() {
    _discountPercent = 0.0;
    _discountFixed = 0.0;
    _commit();
  }

  // ── Hold / Recall ─────────────────────────────────────────────────────────

  bool holdCurrentCart() {
    if (_items.isEmpty) return false;
    _heldCarts.add(List<CartItem>.from(_items));
    _items.clear();
    clearDiscount();
    clearTableInfo();
    _commit();
    return true;
  }

  void recallHeldCart(int index) {
    if (index >= 0 && index < _heldCarts.length) {
      _items.clear();
      _items.addAll(_heldCarts.removeAt(index));
      _commit();
    }
  }

  // ── Clear ────────────────────────────────────────────────────────────────

  void clearCart({bool syncCfd = true}) {
    _items.clear();
    _discountPercent = 0.0;
    _discountFixed = 0.0;
    clearTableInfo();
    if (syncCfd) {
      _syncWithCustomerDisplay();
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  bool _validIndex(int index) => index >= 0 && index < _items.length;

  void _commit() {
    _syncWithCustomerDisplay();
    notifyListeners();
  }

  void _syncWithCustomerDisplay() {
    final payload = PresentationPayload(
      state: _items.isEmpty ? CfdScreenState.idle : CfdScreenState.cartActive,
      items: _items.map((i) => i.toPresentationMap()).toList(),
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      totalAmount: totalAmount,
      currencySymbol: _currencySymbol,
    );
    _presentationService.sendToCustomerDisplay(payload);
  }
}
