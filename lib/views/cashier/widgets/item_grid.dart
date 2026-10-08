import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/register_controller.dart';
import '../../register/open_register_dialog.dart';
import 'category_bar.dart';
import 'product_grid.dart';
import 'subcategory_bar.dart';

export 'category_bar.dart';
export 'product_card.dart';
export 'product_grid.dart';
export 'subcategory_bar.dart';

class ItemGrid extends StatelessWidget {
  final bool isCustomerDisplay;
  final String? gridTemplateOverride;
  final ScrollController? scrollController;

  const ItemGrid({
    super.key,
    this.isCustomerDisplay = false,
    this.gridTemplateOverride,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.watch<PosController>();
    final register = context.watch<RegisterController>();
    final isClosed = !isCustomerDisplay && !register.isSessionOpen;

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

          // Register closed warning banner
          if (isClosed)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_clock_rounded,
                      size: 18,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Register is Closed — Can't Order",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Open register to start taking orders.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => OpenRegisterDialog.show(context),
                    icon: const Icon(Icons.meeting_room_rounded, size: 15),
                    label: const Text(
                      'Open Register',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Product cards grid
          Expanded(
            child: ProductGrid(
              posCtrl: posCtrl,
              isCustomerDisplay: isCustomerDisplay,
              gridTemplateOverride: gridTemplateOverride,
              scrollController: scrollController,
            ),
          ),
        ],
      ),
    );
  }
}
