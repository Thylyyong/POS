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

class CartTotalsPanel extends StatefulWidget {
  final String currency;

  const CartTotalsPanel({super.key, required this.currency});

  @override
  State<CartTotalsPanel> createState() => _CartTotalsPanelState();
}

class _CartTotalsPanelState extends State<CartTotalsPanel> {
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

  void _showDiscountDialog(BuildContext context, CartController cart) {
    final textCtrl = TextEditingController(
      text: cart.discountPercent > 0
          ? cart.discountPercent.toStringAsFixed(0)
          : (cart.discountFixed > 0 ? cart.discountFixed.toStringAsFixed(2) : ''),
    );
    bool isPercent = cart.discountFixed == 0 || cart.discountPercent > 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDFA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.percent, color: Color(0xFF0D9488), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Apply Discount',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Toggle Type: Percentage % vs Fixed $
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => isPercent = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isPercent ? const Color(0xFF0D9488) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Percentage (%)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isPercent ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setDialogState(() => isPercent = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !isPercent ? const Color(0xFF0D9488) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Fixed Amount (${widget.currency})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: !isPercent ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick Preset Chips for %
                if (isPercent) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [5, 10, 15, 20, 25].map((pct) {
                      return InkWell(
                        onTap: () {
                          textCtrl.text = pct.toString();
                          setDialogState(() {});
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Text(
                            '$pct%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Number Input
                TextField(
                  controller: textCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    labelText: isPercent ? 'Discount Percentage (%)' : 'Discount Amount (${widget.currency})',
                    suffixText: isPercent ? '%' : widget.currency,
                    suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.8),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (cart.discountAmount > 0)
                TextButton(
                  onPressed: () {
                    cart.clearDiscount();
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Remove Discount', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  final val = double.tryParse(textCtrl.text.trim()) ?? 0.0;
                  if (isPercent) {
                    cart.setDiscountPercent(val);
                  } else {
                    cart.setDiscountFixed(val);
                  }
                  Navigator.of(ctx).pop();
                },
                child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
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
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtotal
          _buildSummaryRow('Subtotal', '$curr${cart.subtotal.toStringAsFixed(2)}'),
          
          // ── Discount Bar / Insertion Row ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: isEmpty ? null : () => _showDiscountDialog(context, cart),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cart.discountAmount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: cart.discountAmount > 0 ? const Color(0xFFFECACA) : const Color(0xFF99F6E4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.percent,
                              size: 13,
                              color: cart.discountAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF0D9488),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cart.discountPercent > 0
                                  ? 'Discount (${cart.discountPercent.toStringAsFixed(0)}%)'
                                  : (cart.discountFixed > 0 ? 'Discount (Fixed)' : 'Add % Discount'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: cart.discountAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF0D9488),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (cart.discountAmount > 0) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => cart.clearDiscount(),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.cancel, size: 16, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  cart.discountAmount > 0 ? '-$curr${cart.discountAmount.toStringAsFixed(2)}' : '$curr 0.00',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cart.discountAmount > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                    fontWeight: cart.discountAmount > 0 ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
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
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              Text(
                '$curr${cart.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Checkout Action Buttons ──────────────────────────────────────────
          // Row 1: Hold / Save Order
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF334155),
                backgroundColor: const Color(0xFFF1F5F9),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: !isEmpty && !_isProcessing ? _handleSaveAsPending : null,
              icon: const Icon(Icons.bookmark_border, size: 17, color: Color(0xFF334155)),
              label: const Text(
                'Hold Order (Pay Later)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
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
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF0F766E).withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: !isEmpty && !_isProcessing ? _handleCashCheckout : null,
                    icon: const Icon(Icons.payments_outlined, size: 18),
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
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.35),
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
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: isHighlight ? const Color(0xFFEF4444) : const Color(0xFF64748B),
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              color: isHighlight ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
