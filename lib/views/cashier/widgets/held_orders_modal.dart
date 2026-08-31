import 'package:flutter/material.dart';
import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';

void showHeldOrdersModal(BuildContext context, CartController cart) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Row(
        children: [
          Icon(Icons.pause_circle_outline, color: AppConfig.accentAmber),
          SizedBox(width: 8),
          Text(
            'Held Orders',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
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
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Total: \$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: ColorTheme.primary400,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorTheme.buttonPrimary,
                        foregroundColor: Colors.white,
                      ),
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

