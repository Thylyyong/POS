import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../controllers/table_controller.dart';
import '../../../models/order_model.dart';
import '../../../models/store_settings_model.dart';
import '../../../widgets/custom_dialogs.dart';
import '../../../widgets/receipt_preview_dialog.dart';
import '../../tables/widgets/assign_table_dialog.dart';

class CartPanel extends StatelessWidget {
  final VoidCallback? onOpenTablePicker;

  const CartPanel({super.key, this.onOpenTablePicker});

  @override
  Widget build(BuildContext context) {
    final currency = context.select<SettingsController, String>(
      (c) => c.settings.currencySymbol,
    );

    return Container(
      width: 400,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      child: Column(
        children: [
          _CartHeader(currency: currency, onOpenTablePicker: onOpenTablePicker),
          const Expanded(child: _CartItemList()),
          _CartTotalsPanel(currency: currency),
        ],
      ),
    );
  }
}

// ============================================================================
// Cart Header
// ============================================================================
class _CartHeader extends StatelessWidget {
  final String currency;
  final VoidCallback? onOpenTablePicker;

  const _CartHeader({required this.currency, this.onOpenTablePicker});

  @override
  Widget build(BuildContext context) {
    final itemCount = context.select<CartController, int>((c) => c.totalItemCount);
    final heldCount = context.select<CartController, int>((c) => c.heldCarts.length);
    final isEmpty = context.select<CartController, bool>((c) => c.isEmpty);
    final cart = context.watch<CartController>();

    final tableName = cart.tableNumber ?? (cart.orderType == 'TAKEAWAY' ? 'Takeaway' : 'Table T01');
    final customer = cart.customerName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate-900 for distinct contrast
        border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        children: [
          // Row 1: Title + count badge + Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart, color: AppConfig.accentGreen, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Current Order',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppConfig.accentGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$itemCount items',
                      style: const TextStyle(
                        color: AppConfig.accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  if (heldCount > 0)
                    IconButton(
                      icon: Badge(
                        label: Text('$heldCount'),
                        child: const Icon(Icons.pause_circle_outline, color: AppConfig.accentAmber, size: 20),
                      ),
                      tooltip: 'Held Orders ($heldCount)',
                      onPressed: () => _showHeldOrdersModal(context, cart),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppConfig.accentRose, size: 20),
                    tooltip: 'Clear Cart',
                    onPressed: isEmpty ? null : () => _confirmClearCart(context, cart),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Table & Customer selector badge
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const AssignTableDialog(),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                children: [
                  Icon(
                    cart.orderType == 'TAKEAWAY' ? Icons.takeout_dining : Icons.table_restaurant,
                    size: 16,
                    color: AppConfig.accentCyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customer != null ? '$tableName • $customer' : tableName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(
                    'Change Table',
                    style: TextStyle(color: AppConfig.accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: AppConfig.accentCyan),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearCart(BuildContext context, CartController cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Clear Cart?', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        content: const Text('This will remove all items from the current cart.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accentRose, foregroundColor: Colors.white),
            onPressed: () {
              cart.clearCart();
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Cart Item List
// ============================================================================
class _CartItemList extends StatelessWidget {
  const _CartItemList();

  @override
  Widget build(BuildContext context) {
    final items = context.watch<CartController>().items;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_shopping_cart, size: 36, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your cart is empty',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap products from menu to add',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, index) {
        return _CartItemTile(item: items[index], index: index);
      },
    );
  }
}

// ============================================================================
// Cart Item Tile
// ============================================================================
class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final int index;

  const _CartItemTile({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final currency = context.select<SettingsController, String>(
      (c) => c.settings.currencySymbol,
    );
    final cart = context.read<CartController>();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product Name & Unit Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$currency${item.unitPrice.toStringAsFixed(2)} each',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Quantity Stepper
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => cart.decrementQuantity(index),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.remove, size: 15, color: Color(0xFF475569)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                      ),
                    ),
                    InkWell(
                      onTap: () => cart.incrementQuantity(index),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.add, size: 15, color: Color(0xFF475569)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Line Total
              SizedBox(
                width: 60,
                child: Text(
                  '$currency${item.totalPrice.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => cart.removeItem(index),
              ),
            ],
          ),

          // Notes
          if (item.notes != null && item.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Note: ${item.notes}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Cart Totals Panel & Checkout Buttons
// ============================================================================
class _CartTotalsPanel extends StatefulWidget {
  final String currency;

  const _CartTotalsPanel({required this.currency});

  @override
  State<_CartTotalsPanel> createState() => _CartTotalsPanelState();
}

class _CartTotalsPanelState extends State<_CartTotalsPanel> {
  bool _isProcessing = false;

  Future<void> _handleSaveAsPending() async {
    if (_isProcessing) return;
    final cart = context.read<CartController>();
    final posCtrl = context.read<PosController>();
    final settings = context.read<SettingsController>().settings;
    final tableCtrl = context.read<TableController>();

    setState(() => _isProcessing = true);
    try {
      final order = await posCtrl.saveOrderAsPending(
        cart: cart,
        settings: settings,
        tableController: tableCtrl,
      );

      if (order != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Order #${order.orderNumber ?? order.receiptNo} saved for ${order.tableNumber ?? "Table"}!'),
              ],
            ),
            backgroundColor: AppConfig.accentAmber,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCashCheckout() async {
    if (_isProcessing) return;
    final cart = context.read<CartController>();
    final posCtrl = context.read<PosController>();
    final settings = context.read<SettingsController>().settings;
    final tableCtrl = context.read<TableController>();

    final tendered = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CashPaymentDialog(
        totalAmount: cart.totalAmount,
        currencySymbol: settings.currencySymbol,
        onConfirmPayment: (amount) {},
      ),
    );

    if (tendered == null || !mounted) {
      posCtrl.syncCartWithCustomerDisplay(cart);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final order = await posCtrl.processCheckout(
        cart: cart,
        settings: settings,
        paymentMethod: PaymentMethod.cash,
        cashTendered: tendered,
        tableController: tableCtrl,
      );
      if (order != null && mounted) {
        _showReceiptPreview(order, settings, posCtrl);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleQrCheckout() async {
    if (_isProcessing) return;
    final cart = context.read<CartController>();
    final posCtrl = context.read<PosController>();
    final settings = context.read<SettingsController>().settings;
    final tableCtrl = context.read<TableController>();

    final qrPayload =
        '${settings.qrPayloadTemplate}${DateTime.now().millisecondsSinceEpoch}&amount=${cart.totalAmount.toStringAsFixed(2)}';
    posCtrl.showPaymentOnCustomerDisplay(cart: cart, qrPayload: qrPayload);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QrPaymentDialog(
        totalAmount: cart.totalAmount,
        currencySymbol: settings.currencySymbol,
        qrPayload: qrPayload,
        onPaymentConfirmed: () => Navigator.of(context).pop(true),
      ),
    );

    if (confirmed != true || !mounted) {
      posCtrl.syncCartWithCustomerDisplay(cart);
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final order = await posCtrl.processCheckout(
        cart: cart,
        settings: settings,
        paymentMethod: PaymentMethod.qr,
        tableController: tableCtrl,
      );
      if (order != null && mounted) {
        _showReceiptPreview(order, settings, posCtrl);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showReceiptPreview(
    OrderModel order,
    StoreSettingsModel settings,
    PosController posCtrl,
  ) {
    showDialog(
      context: context,
      builder: (_) => ReceiptPreviewDialog(
        order: order,
        settings: settings,
        existingSaveResult: posCtrl.lastReceiptSaveResult,
        onReprint: () => posCtrl.reprintReceipt(order: order, settings: settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final isEmpty = cart.isEmpty;
    final curr = widget.currency;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtotal
          _buildSummaryRow('Subtotal', '$curr${cart.subtotal.toStringAsFixed(2)}'),
          if (cart.discountAmount > 0)
            _buildSummaryRow(
              cart.discountPercent > 0 ? 'Discount (${cart.discountPercent.toStringAsFixed(0)}%)' : 'Discount',
              '-$curr${cart.discountAmount.toStringAsFixed(2)}',
              isHighlight: true,
            ),
          if (cart.taxAmount > 0)
            _buildSummaryRow('Tax (${cart.taxRate.toStringAsFixed(0)}%)', '$curr${cart.taxAmount.toStringAsFixed(2)}'),
          const Divider(height: 14, color: Color(0xFFCBD5E1)),

          // Total Due
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL DUE',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text(
                '$curr${cart.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppConfig.accentGreenDark),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Checkout Action Buttons ──────────────────────────────────────────
          // Row 1: Hold / Save Order (allows creating order 001, then taking order 002 without immediate payment!)
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConfig.accentAmber,
                side: const BorderSide(color: AppConfig.accentAmber, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: !isEmpty && !_isProcessing ? _handleSaveAsPending : null,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text(
                'Save / Hold Order (Pay Later)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Row 2: Cash & QR Payment buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.accentGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppConfig.accentGreen.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: !isEmpty && !_isProcessing ? _handleCashCheckout : null,
                    icon: const Icon(Icons.payments, size: 18),
                    label: const Text('CASH PAY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.accentCyan,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppConfig.accentCyan.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: !isEmpty && !_isProcessing ? _handleQrCheckout : null,
                    icon: const Icon(Icons.qr_code_2, size: 18),
                    label: const Text('QR CODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isHighlight ? AppConfig.accentRose : const Color(0xFF64748B),
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: isHighlight ? AppConfig.accentRose : const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Held orders modal
// ============================================================================
void _showHeldOrdersModal(BuildContext context, CartController cart) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Row(
        children: [
          Icon(Icons.pause_circle_outline, color: AppConfig.accentAmber),
          SizedBox(width: 8),
          Text('Held Orders', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: cart.heldCarts.isEmpty
            ? const Text('No held orders', style: TextStyle(color: Color(0xFF94A3B8)))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: cart.heldCarts.length,
                itemBuilder: (_, index) {
                  final held = cart.heldCarts[index];
                  final total = held.fold(0.0, (sum, i) => sum + i.totalPrice);
                  return ListTile(
                    title: Text(
                      'Held Order #${index + 1} (${held.length} items)',
                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Total: \$${total.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppConfig.accentGreenDark, fontWeight: FontWeight.w600),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accentGreen, foregroundColor: Colors.white),
                      onPressed: () {
                        cart.recallHeldCart(index);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Recall'),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
