import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../tables/widgets/assign_table_dialog.dart';
import 'held_orders_modal.dart';

class CartHeader extends StatelessWidget {
  final String currency;
  final VoidCallback? onOpenTablePicker;

  const CartHeader({
    super.key,
    required this.currency,
    this.onOpenTablePicker,
  });

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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF0F172A), // Slate-900 for distinct contrast
        border: const Border(bottom: BorderSide(color: Color.fromRGBO(234, 236, 239, 1))),
      ),
      child: Column(
        children: [
          // Row 1: Title + count badge + Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart, color: Color.fromARGB(255, 209, 223, 218), size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Current Order',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$itemCount items',
                      style: const TextStyle(
                        color: Colors.white,
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
                      onPressed: () => showHeldOrdersModal(context, cart),
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

