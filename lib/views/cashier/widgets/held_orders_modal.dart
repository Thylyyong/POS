import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../database/order_dao.dart';
import '../../../models/order_model.dart';
import '../../../widgets/app_svg_icon.dart';

void showHeldOrdersModal(BuildContext context, CartController cart) {
  final orderDao = OrderDao();

  showDialog(
    context: context,
    builder: (ctx) => FutureBuilder<List<OrderModel>>(
      future: orderDao.getPendingOrders(),
      builder: (context, snapshot) {
        final pendingOrders = snapshot.data ?? [];
        final hasHeld = cart.heldCarts.isNotEmpty;
        final hasPending = pendingOrders.isNotEmpty;

        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const AppSvgIcon(AssetTheme.snooze, color: AppConfig.accentAmber, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Pending & Held Orders',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (hasPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Text(
                    '${pendingOrders.length} Unpaid',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: (!hasHeld && !hasPending)
                ? (snapshot.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                        ),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Text(
                            'No pending or held orders',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                          ),
                        ),
                      ))
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasPending) ...[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8.0, top: 4.0),
                            child: Text(
                              'CONFIRMED PENDING ORDERS (READY TO PAY)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...pendingOrders.map((order) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Order #${order.orderNumber ?? order.receiptNo}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                order.tableNumber ?? 'Takeaway',
                                                style: const TextStyle(
                                                  color: Color(0xFF92400E),
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${order.items.length} items • \$${order.totalAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Color(0xFF0F766E),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F766E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      final posCtrl = context.read<PosController>();
                                      posCtrl.loadPendingOrderIntoCart(order, cart);
                                      cart.setTableInfo(
                                        tableId: order.tableId,
                                        tableNumber: order.tableNumber,
                                        customerName: order.customerName,
                                        orderType: order.orderType,
                                      );
                                      Navigator.of(ctx).pop();
                                    },
                                    icon: const Icon(Icons.payment, size: 16),
                                    label: const Text(
                                      'Open & Pay',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        if (hasHeld) ...[
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                            child: Text(
                              'LOCAL HELD CARTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...cart.heldCarts.asMap().entries.map((entry) {
                            final index = entry.key;
                            final held = entry.value;
                            final total = held.fold(0.0, (sum, i) => sum + i.totalPrice);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Held Cart #${index + 1} (${held.length} items)',
                                          style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Total: \$${total.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: ColorTheme.primary400,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ColorTheme.buttonPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      cart.recallHeldCart(index);
                                      Navigator.of(ctx).pop();
                                    },
                                    child: const Text('Recall'),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ],
        );
      },
    ),
  );
}

