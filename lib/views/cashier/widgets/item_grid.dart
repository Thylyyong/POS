import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/pos_controller.dart';
import 'category_bar.dart';
import 'product_grid.dart';
import 'subcategory_bar.dart';

export 'category_bar.dart';
export 'product_card.dart';
export 'product_grid.dart';
export 'subcategory_bar.dart';

class ItemGrid extends StatelessWidget {
  const ItemGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.watch<PosController>();

    return Container(
      color: ColorTheme.screenBg,
      child: Column(
        children: [
          // Category filter bar
          CategoryBar(
            categories: posCtrl.categories,
            selectedId: posCtrl.selectedCategoryId,
            onSelect: posCtrl.selectCategory,
          ),

          // Subcategory filter bar (visible when a category is selected)
          if (posCtrl.selectedCategoryId != 'ALL')
            SubcategoryBar(
              subcategories: posCtrl.subcategories
                  .where((s) => s.categoryId == posCtrl.selectedCategoryId)
                  .toList(),
              selectedId: posCtrl.selectedSubcategoryId,
              onSelect: posCtrl.selectSubcategory,
            ),

          // Product cards grid
          Expanded(
            child: ProductGrid(posCtrl: posCtrl),
          ),
        ],
      ),
    );
  }
}
