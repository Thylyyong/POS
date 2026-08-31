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
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                foregroundColor: const Color(0xFF475569),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: !isEmpty && !_isProcessing ? _handleSaveAsPending : null,
              icon: const Icon(Icons.bookmark_border, size: 17),
              label: const Text(
                'Hold Order (Pay Later)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
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
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.35),
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
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.35),
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

