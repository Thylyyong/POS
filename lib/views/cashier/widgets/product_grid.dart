import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/settings_controller.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  final PosController posCtrl;

  const ProductGrid({super.key, required this.posCtrl});

  @override
  Widget build(BuildContext context) {
    final currency = context.select<SettingsController, String>(
      (c) => c.settings.currencySymbol,
    );
    final cart = context.read<CartController>();
    final gridTemplate = context.select<SettingsController, String>(
      (c) => c.settings.gridTemplate,
    );

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: posCtrl.isLoading
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(color: ColorTheme.buttonPrimary),
              )
            : posCtrl.products.isEmpty
                ? Center(
                    key: const ValueKey('empty'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu_outlined,
                          size: 52,
                          color: ColorTheme.neutral400.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No menu items found',
                          style: TextStyle(color: ColorTheme.neutral600, fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    key: const ValueKey('grid'),
                    builder: (context, constraints) {
                      int crossAxisCount = 4;
                      double childAspectRatio = 0.78;

                      if (gridTemplate == '3x6') {
                        crossAxisCount = 3;
                        childAspectRatio = 0.82;
                      } else if (gridTemplate == '5x5') {
                        crossAxisCount = 5;
                        childAspectRatio = 0.75;
                      } else {
                        crossAxisCount = 4;
                        childAspectRatio = 0.78;
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: posCtrl.products.length,
                        itemBuilder: (_, index) {
                          final product = posCtrl.products[index];
                          return ProductCard(
                            product: product,
                            currency: currency,
                            onTap: () => cart.addProduct(product),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

