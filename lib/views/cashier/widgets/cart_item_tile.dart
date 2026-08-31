import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/settings_controller.dart';

class CartItemTile extends StatelessWidget {
  final CartItem item;
  final int index;

  const CartItemTile({
    super.key,
    required this.item,
    required this.index,
  });

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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
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
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

