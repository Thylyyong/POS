import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../models/product_model.dart';

class ItemGrid extends StatefulWidget {
  const ItemGrid({super.key});

  @override
  State<ItemGrid> createState() => _ItemGridState();
}

class _ItemGridState extends State<ItemGrid> {
  @override
  Widget build(BuildContext context) {
    final posCtrl = context.watch<PosController>();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Search is handled in the TopHeaderBar; here we show category/subcategory filters
          _CategoryBar(
            categories: posCtrl.categories,
            selectedId: posCtrl.selectedCategoryId,
            onSelect: posCtrl.selectCategory,
          ),
          if (posCtrl.selectedCategoryId != 'ALL')
            _SubcategoryBar(
              subcategories: posCtrl.subcategories
                  .where((s) => s.categoryId == posCtrl.selectedCategoryId)
                  .toList(),
              selectedId: posCtrl.selectedSubcategoryId,
              onSelect: posCtrl.selectSubcategory,
            ),
          Expanded(child: _ProductGrid(posCtrl: posCtrl)),
        ],
      ),
    );
  }
}

// ============================================================================
// Category tab bar
// ============================================================================
class _CategoryBar extends StatelessWidget {
  final List<Category> categories;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _CategoryBar({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CategoryChip(
            label: 'All',
            isSelected: selectedId == 'ALL',
            onTap: () => onSelect('ALL'),
          ),
          ...categories.map(
            (cat) => _CategoryChip(
              label: cat.name,
              isSelected: selectedId == cat.id,
              onTap: () => onSelect(cat.id),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Subcategory pill bar
// ============================================================================
class _SubcategoryBar extends StatelessWidget {
  final List<Subcategory> subcategories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _SubcategoryBar({
    required this.subcategories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (subcategories.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _SubcategoryPill(
            label: 'All',
            isSelected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          ...subcategories.map(
            (s) => _SubcategoryPill(
              label: s.name,
              isSelected: selectedId == s.id,
              onTap: () => onSelect(s.id),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Product grid
// ============================================================================
class _ProductGrid extends StatelessWidget {
  final PosController posCtrl;

  const _ProductGrid({required this.posCtrl});

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
                child: CircularProgressIndicator(color: Color(0xFF0F172A)),
              )
            : posCtrl.products.isEmpty
                ? Center(
                    key: const ValueKey('empty'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu_outlined,
                            size: 52,
                            color: const Color(0xFF94A3B8).withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'No menu items found',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    key: const ValueKey('grid'),
                    builder: (context, constraints) {
                      int crossAxisCount = 4;
                      double childAspectRatio = 0.80;

                      if (gridTemplate == '3x6') {
                        crossAxisCount = 3;
                        childAspectRatio = 0.85;
                      } else if (gridTemplate == '5x5') {
                        crossAxisCount = 5;
                        childAspectRatio = 0.78;
                      } else {
                        crossAxisCount = 4;
                        childAspectRatio = 0.80;
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
                          return _ProductCard(
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

// ============================================================================
// Clean Product Card – no SKU badge, neutral placeholder, subtle stock tag
// ============================================================================
class _ProductCard extends StatelessWidget {
  final Product product;
  final String currency;
  final VoidCallback onTap;

  const _ProductCard({
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
    final hasDesc = product.description != null && product.description!.trim().isNotEmpty;

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
              border: Border.all(color: const Color(0xFFE8EDF2)),
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
                // ── Image / Placeholder ─────────────────────────────────
                Expanded(
                  flex: 6,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Photo or clean neutral placeholder
                        imgProvider != null
                            ? Image(
                                image: imgProvider,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 38,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 38,
                                    color: Color(0xFFCBD5E1),
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
                                color: AppConfig.accentRose,
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

                // ── Footer ──────────────────────────────────────────────
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Product name + optional subtitle
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.name,
                              maxLines: hasDesc ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            if (hasDesc) ...[
                              const SizedBox(height: 1),
                              Text(
                                product.description!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // Price + add button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$currency${product.price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!isOutOfStock)
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(Icons.add, size: 15, color: Colors.white),
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

// ============================================================================
// Category chip (text only – no icon)
// ============================================================================
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Subcategory pill
// ============================================================================
class _SubcategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubcategoryPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFF1F5F9)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
