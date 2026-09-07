import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_svg_icon.dart';
import '../../tables/widgets/assign_table_dialog.dart';
import 'held_orders_modal.dart';

class CartHeader extends StatelessWidget {
  final String currency;
  final VoidCallback? onOpenTablePicker;

  const CartHeader({super.key, required this.currency, this.onOpenTablePicker});

  @override
  Widget build(BuildContext context) {
    final itemCount = context.select<CartController, int>(
      (c) => c.totalItemCount,
    );
    final heldCount = context.select<CartController, int>(
      (c) => c.heldCarts.length,
    );
    final isEmpty = context.select<CartController, bool>((c) => c.isEmpty);
    final cart = context.watch<CartController>();

    final tableName =
        cart.tableNumber ??
        (cart.orderType == 'TAKEAWAY'
            ? 'Takeaway'
            : cart.orderType == 'DELIVERY'
            ? 'Delivery'
            : 'Table T01');
    final customer = cart.customerName;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Row 1: Title + count badge + Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const AppSvgIcon(
                      AssetTheme.cart,
                      color: ColorTheme.primary400,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Current Order',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: ColorTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF99F6E4)),
                      ),
                      child: Text(
                        '$itemCount items',
                        style: const TextStyle(
                          color: ColorTheme.primary400,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (heldCount > 0)
                    IconButton(
                      icon: Badge(
                        label: Text('$heldCount'),
                        child: const AppSvgIcon(
                          AssetTheme.snooze,
                          color: AppConfig.accentAmber,
                          size: 22,
                        ),
                      ),
                      tooltip: 'Held Orders ($heldCount)',
                      onPressed: () => showHeldOrdersModal(context, cart),
                    ),
                  IconButton(
                    icon: const AppSvgIcon(
                      AssetTheme.bin,
                      color: AppConfig.accentRose,
                      size: 22,
                    ),
                    tooltip: 'Clear Cart',
                    onPressed: isEmpty
                        ? null
                        : () => _confirmClearCart(context, cart),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: Table & Customer selector badge (Light Theme)
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const AssignTableDialog(),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  cart.orderType == 'TAKEAWAY'
                      ? const AppSvgIcon(
                          AssetTheme.packageIcon,
                          size: 19,
                          color: ColorTheme.primary400,
                        )
                      : cart.orderType == 'DELIVERY'
                      ? const AppSvgIcon(
                          AssetTheme.delivery,
                          size: 19,
                          color: ColorTheme.primary400,
                        )
                      : const Icon(
                          Icons.table_restaurant_outlined,
                          size: 20,
                          color: ColorTheme.primary400,
                        ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customer != null ? '$tableName • $customer' : tableName,
                      style: const TextStyle(
                        color: ColorTheme.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text(
                    'Change Table',
                    style: TextStyle(
                      color: ColorTheme.primary400,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const AppSvgIcon(
                    AssetTheme.chevronRight,
                    size: 16,
                    color: ColorTheme.primary400,
                  ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Clear Cart?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ColorTheme.textPrimary,
          ),
        ),
        content: const Text(
          'All items in the current order will be removed.',
          style: TextStyle(color: ColorTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              cart.clearCart();
              Navigator.of(ctx).pop();
            },
            child: const Text(
              'Clear',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
