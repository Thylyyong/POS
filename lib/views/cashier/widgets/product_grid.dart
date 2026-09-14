import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/settings_controller.dart';
import 'product_card.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_svg_icon.dart';

class ProductGrid extends StatefulWidget {
  final PosController posCtrl;
  final bool isCustomerDisplay;
  final String? gridTemplateOverride;
  final ScrollController? scrollController;

  const ProductGrid({
    super.key,
    required this.posCtrl,
    this.isCustomerDisplay = false,
    this.gridTemplateOverride,
    this.scrollController,
  });

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
  State<ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<ProductGrid> {
  late ScrollController _scrollController;
  bool _isInternalScrollController = false;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
      _isInternalScrollController = false;
    } else {
      _scrollController = ScrollController();
      _isInternalScrollController = true;
    }

    if (!widget.isCustomerDisplay) {
      _scrollController.addListener(_onCashierScroll);
    }
  }

  void _onCashierScroll() {
    if (_scrollController.hasClients) {
      widget.posCtrl.setScrollOffset(_scrollController.offset);
    }
  }

  @override
  void didUpdateWidget(covariant ProductGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCustomerDisplay) {
      // Synchronize customer duplicate screen scroll offset from POS
      final targetOffset = widget.posCtrl.scrollOffset;
      if (_scrollController.hasClients) {
        if ((_scrollController.offset - targetOffset).abs() > 4.0) {
          final maxExtent = _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(targetOffset.clamp(0.0, maxExtent));
        }
      }
    } else {
      // If category changed and reset to 0, jump cashier to 0
      if (widget.posCtrl.scrollOffset == 0.0 &&
          _scrollController.hasClients &&
          _scrollController.offset > 0.0) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    if (!widget.isCustomerDisplay) {
      _scrollController.removeListener(_onCashierScroll);
    }
    if (_isInternalScrollController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.select<SettingsController, String>(
      (c) => c.settings.currencySymbol,
    );
    final cart = context.read<CartController>();
    final settingsGridTemplate = context.select<SettingsController, String>(
      (c) => c.settings.gridTemplate,
    );
    final gridTemplate = widget.gridTemplateOverride ?? settingsGridTemplate;

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: widget.posCtrl.isLoading
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(color: ColorTheme.buttonPrimary),
              )
            : widget.posCtrl.products.isEmpty
                ? Center(
                    key: const ValueKey('empty'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppSvgIcon(
                          AssetTheme.allCate,
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
                      final layout = ProductGrid.resolveGridLayout(
                        maxWidth: constraints.maxWidth,
                        gridTemplate: gridTemplate,
                      );

                      return GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: layout.crossAxisCount,
                          childAspectRatio: layout.childAspectRatio,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: widget.posCtrl.products.length,
                        itemBuilder: (_, index) {
                          final product = widget.posCtrl.products[index];
                          return ProductCard(
                            product: product,
                            currency: currency,
                            onTap: widget.isCustomerDisplay
                                ? () {}
                                : () => cart.addProduct(product),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}

