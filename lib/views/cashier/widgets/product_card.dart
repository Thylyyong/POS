import 'package:flutter/material.dart';

import '../../../app_config.dart';
import '../../../core/product_image_helper.dart';
import '../../../models/product_model.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_svg_icon.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final String currency;
  final VoidCallback onTap;

  const ProductCard({
    super.key,
    required this.product,
    required this.currency,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imgProvider = ProductImageHelper.resolveImageProvider(
      imagePath: product.imagePath,
      productName: product.name,
      categoryId: product.categoryId,
    );

    final bool isOutOfStock = !product.inStock;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOutOfStock ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: isOutOfStock ? 0.55 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Image Container (Shows FULL image cleanly) ───────────
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13),
                    ),
                    child: Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.all(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(
                            image: imgProvider,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset(
                              ProductImageHelper.getDefaultAssetFor(
                                productName: product.name,
                                categoryId: product.categoryId,
                              ),
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Center(
                                child: AppSvgIcon(
                                  AssetTheme.gallery,
                                  size: 40,
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                            ),
                          ),

                          // Available Stock Badge for Cashiers / Staff
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: isOutOfStock
                                    ? const Color(0xFFEF4444)
                                    : (product.stockQuantity <= 5
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF0F172A).withValues(alpha: 0.72)),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isOutOfStock
                                        ? Icons.remove_circle_outline_rounded
                                        : (product.stockQuantity <= 5
                                            ? Icons.warning_amber_rounded
                                            : Icons.inventory_2_outlined),
                                    color: Colors.white,
                                    size: 11,
                                  ),
                                  const SizedBox(width: 3.5),
                                  Text(
                                    isOutOfStock
                                        ? '0 left'
                                        : '${product.stockQuantity} left',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // OUT OF STOCK overlay
                          if (isOutOfStock)
                            Container(
                              color: Colors.white.withValues(alpha: 0.65),
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorTheme.semanticRed,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'OUT OF STOCK',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Content Footer (Title, Price, Clean '+' Button) ───────
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product name
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Price & Add Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Price text
                          Expanded(
                            child: Text(
                              '$currency${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF0D9488),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // '+' Button
                          if (!isOutOfStock)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onTap,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D9488),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0D9488)
                                            .withValues(alpha: 0.25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1.5),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: AppSvgIcon(
                                      AssetTheme.plus,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
