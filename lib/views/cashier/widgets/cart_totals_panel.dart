import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/cart_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../controllers/table_controller.dart';
import '../../../models/order_model.dart';
import '../../../models/store_settings_model.dart';
import '../../../widgets/custom_dialogs.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../core/theme/sprite_icons.dart';
import '../../../widgets/app_svg_icon.dart';
import '../../../widgets/receipt_preview_dialog.dart';
import '../../../services/printer_service.dart';

class CartTotalsPanel extends StatefulWidget {
  final String currency;

  const CartTotalsPanel({super.key, required this.currency});

  @override
  State<CartTotalsPanel> createState() => _CartTotalsPanelState();
}

class _CartTotalsPanelState extends State<CartTotalsPanel> {
  bool _isProcessing = false;

  Future<void> _handlePrintBill({bool showQr = true}) async {
    if (_isProcessing) return;
    final cart = context.read<CartController>();
    if (cart.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            AppSvgIcon.sprite(
              showQr ? SpriteIcons.khqr : SpriteIcons.receipt,
              color: const Color(0xFF0F766E),
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              showQr ? 'Print Bill (With QR)' : 'Print Bill (No QR)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showQr
                  ? 'Print a bill receipt with Bakong KHQR for customer review and mobile banking payment?'
                  : 'Print a bill receipt without QR code for customer review and payment?',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Table / Destination:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      Text(
                        cart.tableNumber ?? (cart.orderType == 'TAKEAWAY' ? 'Takeaway' : 'Table T01'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Items:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      Text('${cart.totalItemCount} items', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order Total:', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                      Text('${widget.currency}${cart.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showQr
                  ? '* Prints Bill with Bakong KHQR. Order is kept pending until customer pays.'
                  : '* Prints Bill without QR code. Order is kept pending until customer pays.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.print, size: 16),
            label: Text(showQr ? 'Print Bill (QR)' : 'Print Bill (No QR)', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final posCtrl = context.read<PosController>();
    final settings = context.read<SettingsController>().settings;
    final branchId = context.read<AuthController>().currentBranchId;
    final tableCtrl = context.read<TableController>();

    setState(() => _isProcessing = true);
    try {
      final order = await posCtrl.printUnpaidBill(
        cart: cart,
        settings: settings,
        branchId: branchId,
        tableController: tableCtrl,
        clearCartAfter: false,
        showQr: showQr,
      );

      if (order != null && mounted) {
        _showReceiptPreview(
          order,
          settings,
          posCtrl,
          initialIsPaid: false,
          initialMode: showQr ? ReceiptMode.unpaidQr : ReceiptMode.unpaidNoQr,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReprintBill() async {
    if (_isProcessing) return;
    final posCtrl = context.read<PosController>();
    final settings = context.read<SettingsController>().settings;
    final order = posCtrl.lastCompletedOrder;

    if (order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.print_outlined, color: Color(0xFF0F766E), size: 22),
            SizedBox(width: 8),
            Text('Reprint Bill (Unpaid / QR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Print another copy of Bill #${order.orderNumber ?? order.receiptNo} with Bakong KHQR?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Confirm & Print', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final printerService = PrinterService();
    await printerService.printReceipt(order: order, settings: settings, isPaid: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unpaid bill reprinted!'),
          backgroundColor: Color(0xFF0F766E),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleNewOrder() {
    final cart = context.read<CartController>();
    cart.clearCart();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New order started. Previous order is pending on Table/History.'),
        backgroundColor: Color(0xFF334155),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleCashCheckout() async {
    if (_isProcessing) return;
    final cart = context.read<CartController>();
    final posCtrl = context.read<PosController>();
    final settings = context.read<SettingsController>().settings;
    final branchId = context.read<AuthController>().currentBranchId;
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
        branchId: branchId,
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
    final branchId = context.read<AuthController>().currentBranchId;
    final tableCtrl = context.read<TableController>();

    final qrPayload =
        '${settings.qrPayloadTemplate}${DateTime.now().millisecondsSinceEpoch}&amount=${cart.totalAmount.toStringAsFixed(2)}';
    posCtrl.showPaymentOnCustomerDisplay(
      cart: cart,
      qrPayload: qrPayload,
      qrImagePath: settings.qrImagePath,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QrPaymentDialog(
        totalAmount: cart.totalAmount,
        currencySymbol: settings.currencySymbol,
        qrPayload: qrPayload,
        qrImagePath: settings.qrImagePath,
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
        branchId: branchId,
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
    PosController posCtrl, {
    bool initialIsPaid = true,
    ReceiptMode? initialMode,
  }) {
    showDialog(
      context: context,
      builder: (_) => ReceiptPreviewDialog(
        order: order,
        settings: settings,
        initialIsPaid: initialIsPaid,
        initialMode: initialMode,
        existingSaveResult: posCtrl.lastReceiptSaveResult,
        onReprint: () =>
            posCtrl.reprintReceipt(order: order, settings: settings, isPaid: initialIsPaid),
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, CartController cart) {
    final textCtrl = TextEditingController(
      text: cart.discountPercent > 0
          ? cart.discountPercent.toStringAsFixed(0)
          : (cart.discountFixed > 0
                ? cart.discountFixed.toStringAsFixed(2)
                : ''),
    );
    bool isPercent = cart.discountFixed == 0 || cart.discountPercent > 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
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
                  child: const AppSvgIcon(
                    AssetTheme.discount,
                    color: Color(0xFF0D9488),
                    size: 20,
                  ),
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
                            color: isPercent
                                ? const Color(0xFF0D9488)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Percentage (%)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isPercent
                                  ? Colors.white
                                  : const Color(0xFF475569),
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
                            color: !isPercent
                                ? const Color(0xFF0D9488)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Fixed Amount (${widget.currency})',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: !isPercent
                                  ? Colors.white
                                  : const Color(0xFF475569),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    labelText: isPercent
                        ? 'Discount Percentage (%)'
                        : 'Discount Amount (${widget.currency})',
                    suffixText: isPercent ? '%' : widget.currency,
                    suffixStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF0D9488),
                        width: 1.8,
                      ),
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
                  child: const Text(
                    'Remove Discount',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                child: const Text(
                  'Apply',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
          _buildSummaryRow(
            'Subtotal',
            '$curr${cart.subtotal.toStringAsFixed(2)}',
          ),

          // ── Discount Bar / Insertion Row ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: isEmpty
                          ? null
                          : () => _showDiscountDialog(context, cart),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cart.discountAmount > 0
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFF0FDFA),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: cart.discountAmount > 0
                                ? const Color(0xFFFECACA)
                                : const Color(0xFF99F6E4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppSvgIcon(
                              AssetTheme.discount,
                              size: 16,
                              color: cart.discountAmount > 0
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF0D9488),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cart.discountPercent > 0
                                  ? 'Discount (${cart.discountPercent.toStringAsFixed(0)}%)'
                                  : (cart.discountFixed > 0
                                        ? 'Discount (Fixed)'
                                        : 'Add % Discount'),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: cart.discountAmount > 0
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF0D9488),
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
                          child: AppSvgIcon(
                            AssetTheme.close,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  cart.discountAmount > 0
                      ? '-$curr${cart.discountAmount.toStringAsFixed(2)}'
                      : '$curr 0.00',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cart.discountAmount > 0
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF94A3B8),
                    fontWeight: cart.discountAmount > 0
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          if (cart.taxAmount > 0)
            _buildSummaryRow(
              'Tax (${cart.taxRate.toStringAsFixed(0)}%)',
              '$curr${cart.taxAmount.toStringAsFixed(2)}',
            ),
          const Divider(height: 14, color: Color(0xFFCBD5E1)),

          // Total Due
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL DUE',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '$curr${cart.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Checkout Action Buttons ──────────────────────────────────────────
          if (cart.isConfirmedPending) ...[
            // Status banner for confirmed unpaid bill
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCD34D)),
              ),
              child: Row(
                children: [
                  const AppSvgIcon.sprite(SpriteIcons.receipt, size: 18, color: Color(0xFF92400E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bill #${cart.orderNumber ?? ""} Printed • Unpaid',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _handleReprintBill,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'Reprint Bill',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Row 1: Payment buttons: "CASH PAY" and "QR CODE"
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF0F766E)
                            .withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: !_isProcessing ? _handleCashCheckout : null,
                      icon: const AppSvgIcon.sprite(SpriteIcons.cash, size: 21, color: Colors.white),
                      label: const Text(
                        'CASH PAY',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
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
                        disabledBackgroundColor: const Color(0xFF0D9488)
                            .withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      onPressed: !_isProcessing ? _handleQrCheckout : null,
                      icon: const AppSvgIcon.sprite(SpriteIcons.khqr, size: 21, color: Colors.white),
                      label: const Text(
                        'QR CODE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Secondary action: Start New Order
            SizedBox(
              width: double.infinity,
              height: 38,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF475569),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _handleNewOrder,
                icon: const AppSvgIcon.sprite(SpriteIcons.cart, size: 17, color: Color(0xFF475569)),
                label: const Text(
                  'Start New Order (Keep Table Active)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ] else ...[
            // Row 1: PRINT BILL OPTIONS (NO QR vs WITH QR)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFD97706)
                            .withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: !isEmpty && !_isProcessing
                          ? () => _handlePrintBill(showQr: false)
                          : null,
                      icon: const AppSvgIcon.sprite(SpriteIcons.receipt, size: 18, color: Colors.white),
                      label: const Text(
                        'BILL (NO QR)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB45309),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFB45309)
                            .withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onPressed: !isEmpty && !_isProcessing
                          ? () => _handlePrintBill(showQr: true)
                          : null,
                      icon: const AppSvgIcon.sprite(SpriteIcons.khqr, size: 18, color: Colors.white),
                      label: const Text(
                        'BILL (WITH QR)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Row 2: Cash & QR Payment buttons (Immediate Pay)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        backgroundColor: const Color(0xFFF0FDFA),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: !isEmpty && !_isProcessing
                          ? _handleCashCheckout
                          : null,
                      icon: const AppSvgIcon.sprite(SpriteIcons.cash, size: 19, color: Color(0xFF0F766E)),
                      label: const Text(
                        'CASH PAY',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D9488),
                        backgroundColor: const Color(0xFFF0FDFA),
                        side: const BorderSide(color: Color(0xFF0D9488)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: !isEmpty && !_isProcessing
                          ? _handleQrCheckout
                          : null,
                      icon: const AppSvgIcon.sprite(SpriteIcons.khqr, size: 19, color: Color(0xFF0D9488)),
                      label: const Text(
                        'QR CODE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: isHighlight
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF64748B),
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              color: isHighlight
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
