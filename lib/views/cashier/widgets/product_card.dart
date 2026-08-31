import 'dart:io';
import 'package:flutter/material.dart';
import '../../../app_config.dart';
import '../../../models/product_model.dart';

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
    final imagePath = product.imagePath?.trim();
    ImageProvider? imgProvider;
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('assets/')) {
        imgProvider = AssetImage(imagePath);
      } else {
        imgProvider = FileImage(File(imagePath));
      }
    }

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
              color: ColorTheme.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorTheme.neutral300, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Framed Image / Placeholder (with neutral200 frame) ───
                Expanded(
                  flex: 74,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(7, 7, 7, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: ColorTheme.neutral100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ColorTheme.neutral200, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Photo or clean neutral placeholder
                            imgProvider != null
                                ? Image(
                                    image: imgProvider,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: ColorTheme.neutral100,
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 36,
                                          color: ColorTheme.neutral400,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: ColorTheme.neutral100,
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_outlined,
                                        size: 36,
                                        color: ColorTheme.neutral400,
                                      ),
                                    ),
                                  ),

                            // OUT OF STOCK overlay
                            if (isOutOfStock)
                              Container(
                                color: Colors.white.withValues(alpha: 0.55),
                                alignment: Alignment.center,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ColorTheme.semanticRed,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'OUT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Content Footer (Title, Price, Big '+' Button) ────────
                Expanded(
                  flex: 26,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 6, 8, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Product name
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ColorTheme.neutral800,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),

                        // Price & Big Add Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Price text
                            Expanded(
                              child: Text(
                                '$currency${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: ColorTheme.primary400,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // '+' Button (32x32)
                            if (!isOutOfStock)
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: onTap,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: ColorTheme.buttonPrimary,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: ColorTheme.buttonPrimary.withValues(alpha: 0.25),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1.5),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.add,
                                        size: 19,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
