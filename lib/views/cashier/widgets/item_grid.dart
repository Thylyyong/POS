import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../core/debouncer.dart';
import '../../../models/product_model.dart';

class ItemGrid extends StatefulWidget {
  const ItemGrid({super.key});

  @override
  State<ItemGrid> createState() => _ItemGridState();
}

class _ItemGridState extends State<ItemGrid> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(duration: const Duration(milliseconds: 300));

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.watch<PosController>();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          _SearchBar(
            controller: _searchController,
            debouncer: _debouncer,
          ),
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
// Search bar
// ============================================================================
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Debouncer debouncer;

  const _SearchBar({required this.controller, required this.debouncer});

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.read<PosController>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SizedBox(
        height: 42,
        child: TextField(
          controller: controller,
          onChanged: (val) => debouncer.call(() => posCtrl.setSearchQuery(val)),
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search menu by item name, SKU or barcode...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(0xFF64748B), size: 18),
                    onPressed: () {
                      controller.clear();
                      debouncer.cancel();
                      posCtrl.clearSearch();
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            fillColor: const Color(0xFFF1F5F9),
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppConfig.accentGreen, width: 2)),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _CategoryChip(
            label: 'All Items',
            icon: Icons.apps,
            isSelected: selectedId == 'ALL',
            onTap: () => onSelect('ALL'),
          ),
          ...categories.map(
            (cat) => _CategoryChip(
              label: cat.name,
              icon: _categoryIcon(cat.icon),
              isSelected: selectedId == cat.id,
              onTap: () => onSelect(cat.id),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _categoryIcon(String? name) {
    switch (name) {
      case 'local_cafe':
        return Icons.local_cafe;
      case 'lunch_dining':
        return Icons.lunch_dining;
      case 'restaurant':
        return Icons.restaurant;
      case 'cake':
        return Icons.cake;
      case 'local_bar':
        return Icons.local_bar;
      default:
        return Icons.fastfood;
    }
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
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
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
// Product grid (4 columns, childAspectRatio: 0.82 for 15.6" 1366x768 screens)
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

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: posCtrl.isLoading
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(color: AppConfig.accentGreen),
              )
            : posCtrl.products.isEmpty
                ? Center(
                    key: const ValueKey('empty'),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fastfood_outlined,
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
                      // Calculate optimal columns: 4 columns for ~820-900px width on 15.6" screens
                      final crossAxisCount = (constraints.maxWidth / 195).floor().clamp(3, 5);

                      return GridView.builder(
                        padding: const EdgeInsets.all(14),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 0.82,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
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
// Modern Product Card (60% Image height with ClipRRect, badge overlay, clean footer)
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
    Color accent = AppConfig.accentGreen;
    if (product.colorHex != null && product.colorHex!.isNotEmpty) {
      try {
        accent = Color(int.parse(product.colorHex!));
      } catch (_) {}
    }

    final imagePath = product.imagePath?.trim();
    ImageProvider? imgProvider;
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('assets/')) {
        imgProvider = AssetImage(imagePath);
      } else if (File(imagePath).existsSync()) {
        imgProvider = FileImage(File(imagePath));
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: product.inStock ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top 60% Image Container with ClipRRect
              Expanded(
                flex: 6,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo or Icon
                      Container(
                        color: accent.withValues(alpha: 0.12),
                        child: imgProvider != null
                            ? Image(
                                image: imgProvider,
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: Icon(Icons.restaurant_menu, size: 36, color: accent),
                              ),
                      ),

                      // Gradient Overlay for readability
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.35),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.15),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.4, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // Top-Left: SKU / Barcode Badge
                      if (product.barcode != null && product.barcode!.isNotEmpty)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.barcode!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                      // Top-Right: Stock / Status Badge
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: product.inStock
                                ? AppConfig.accentGreen.withValues(alpha: 0.9)
                                : AppConfig.accentRose.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.inStock ? 'IN STOCK' : 'OUT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Bottom 40% Card Footer: Title, Price, + Button
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$currency${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppConfig.accentGreenDark,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppConfig.accentGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, size: 18, color: AppConfig.accentGreenDark),
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
    );
  }
}

// ============================================================================
// Category chip
// ============================================================================
class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppConfig.accentGreen : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppConfig.accentGreen : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: isSelected ? Colors.white : const Color(0xFF475569)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
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
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? AppConfig.accentCyan.withValues(alpha: 0.18)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppConfig.accentCyan : const Color(0xFFCBD5E1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppConfig.accentCyan : const Color(0xFF475569),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
