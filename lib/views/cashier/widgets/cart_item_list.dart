import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/cart_controller.dart';
import 'cart_item_tile.dart';

class CartItemList extends StatelessWidget {
  const CartItemList({super.key});

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
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_shopping_cart,
                size: 36,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
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
        return CartItemTile(item: items[index], index: index);
      },
    );
  }
}

