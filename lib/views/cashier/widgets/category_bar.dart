import 'package:flutter/material.dart';
import '../../../app_config.dart';
import '../../../models/product_model.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../widgets/app_svg_icon.dart';

class CategoryBar extends StatefulWidget {
  final List<Category> categories;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const CategoryBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollButtons());
  }

  @override
  void didUpdateWidget(covariant CategoryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollButtons());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtons);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final canLeft = currentScroll > 4;
    final canRight = currentScroll < (maxScroll - 4);
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: const BoxDecoration(
        color: ColorTheme.cardBg,
        border: Border(bottom: BorderSide(color: ColorTheme.neutral300, width: 1)),
      ),
      child: Row(
        children: [
          // Scroll Left Button
          if (_canScrollLeft)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _ScrollNavButton(
                svgAsset: AssetTheme.chevronLeft,
                tooltip: 'Scroll left',
                onPressed: () => _scroll(-220),
              ),
            ),

          // Scrollable category list
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _updateScrollButtons();
                return false;
              },
              child: ListView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                children: [
                  CategoryChip(
                    label: 'All',
                    isSelected: widget.selectedId == 'ALL',
                    onTap: () => widget.onSelect('ALL'),
                  ),
                  ...widget.categories.map(
                    (cat) => CategoryChip(
                      label: cat.name,
                      isSelected: widget.selectedId == cat.id,
                      onTap: () => widget.onSelect(cat.id),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scroll Right Button
          if (_canScrollRight)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _ScrollNavButton(
                svgAsset: AssetTheme.chevronRight,
                tooltip: 'Scroll right',
                onPressed: () => _scroll(220),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Small scroll navigation chevron button ────────────────────────────────────
class _ScrollNavButton extends StatelessWidget {
  final String svgAsset;
  final String tooltip;
  final VoidCallback onPressed;

  const _ScrollNavButton({
    required this.svgAsset,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: ColorTheme.neutral100,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 32,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ColorTheme.neutral300, width: 1),
            ),
            alignment: Alignment.center,
            child: AppSvgIcon(svgAsset, size: 20, color: ColorTheme.primary400),
          ),
        ),
      ),
    );
  }
}

// ── Category Chip ────────────────────────────────────────────────────────────
class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? ColorTheme.buttonPrimary : ColorTheme.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? ColorTheme.buttonPrimary : ColorTheme.neutral300,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ColorTheme.buttonPrimary.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : ColorTheme.primary400,
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

