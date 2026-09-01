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

  static ({int crossAxisCount, double childAspectRatio}) resolveGridLayout({
    required double maxWidth,
    required String gridTemplate,
  }) {
    if (gridTemplate == '3x6') {
      final crossAxisCount = maxWidth < 700
          ? 2
          : maxWidth < 1150
              ? 3
              : 4;
      final childAspectRatio = maxWidth < 700 ? 0.74 : 0.82;
      return (crossAxisCount: crossAxisCount, childAspectRatio: childAspectRatio);
    }

    if (gridTemplate == '5x5') {
      final crossAxisCount = maxWidth < 640
          ? 2
          : maxWidth < 980
              ? 3
              : maxWidth < 1400
                  ? 4
                  : 5;
      final childAspectRatio = maxWidth < 700 ? 0.72 : 0.75;
      return (crossAxisCount: crossAxisCount, childAspectRatio: childAspectRatio);
    }

    final crossAxisCount = maxWidth < 600
        ? 2
        : maxWidth < 980
            ? 3
            : maxWidth < 1400
                ? 4
                : 5;
    final childAspectRatio = maxWidth < 720 ? 0.74 : 0.78;
    return (crossAxisCount: crossAxisCount, childAspectRatio: childAspectRatio);
  }

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
                      final layout = resolveGridLayout(
                        maxWidth: constraints.maxWidth,
                        gridTemplate: gridTemplate,
                      );

                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: layout.crossAxisCount,
                          childAspectRatio: layout.childAspectRatio,
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

