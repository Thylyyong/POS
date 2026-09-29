import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../controllers/cart_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../core/product_image_helper.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_svg_icon.dart';
import '../../../widgets/cart_item_action_dialog.dart';

class CartItemTile extends StatelessWidget {
  final CartItem item;
  final int index;

  const CartItemTile({super.key, required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final currency = context.select<SettingsController, String>(
      (c) => c.settings.currencySymbol,
    );
    final cart = context.read<CartController>();

    final imgProvider = ProductImageHelper.resolveImageProvider(
      imagePath: item.product.imagePath,
      productName: item.product.name,
      categoryId: item.product.categoryId,
    );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product Image Thumbnail (Shows full bottle/item without cropping)
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image(
                    image: imgProvider,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (_, error, stack) => Image.asset(
                      ProductImageHelper.getDefaultAssetFor(
                        productName: item.product.name,
                        categoryId: item.product.categoryId,
                      ),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, error2, stack2) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Product Name & Unit Price (Click to open Numpad / Price / Void)
              Expanded(
                child: InkWell(
                  onTap: () => CartItemActionDialog.show(
                    context,
                    itemIndex: index,
                    item: item,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$currency${item.unitPrice.toStringAsFixed(2)} each',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: SvgPicture.asset(
                          AssetTheme.minus,
                          width: 15,
                          height: 15,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFF475569),
                            BlendMode.srcIn,
                          ),
                        ),
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
                        child: AppSvgIcon(
                          AssetTheme.plus,
                          size: 15,
                          color: Color(0xFF475569),
                        ),
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
