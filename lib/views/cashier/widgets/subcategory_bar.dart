import 'package:flutter/material.dart';
import '../../../app_config.dart';
import '../../../models/product_model.dart';

class SubcategoryBar extends StatelessWidget {
  final List<Subcategory> subcategories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const SubcategoryBar({
    super.key,
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
        color: ColorTheme.neutral100,
        border: Border(bottom: BorderSide(color: ColorTheme.neutral300, width: 1)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          SubcategoryPill(
            label: 'All',
            isSelected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          ...subcategories.map(
            (s) => SubcategoryPill(
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

// ── Subcategory Pill ─────────────────────────────────────────────────────────
class SubcategoryPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const SubcategoryPill({
    super.key,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? ColorTheme.cardBg : ColorTheme.neutral100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? ColorTheme.primary400 : ColorTheme.neutral300,
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? ColorTheme.primary400 : ColorTheme.neutral600,
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

