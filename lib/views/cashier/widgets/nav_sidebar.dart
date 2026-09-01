import 'package:flutter/material.dart';
import '../../../app_config.dart';

enum CashierNavTab {
  pos,
  tables,
  products,
  categories,
  history,
  dashboard,
  settings,
}

class NavSidebar extends StatefulWidget {
  final CashierNavTab currentTab;
  final ValueChanged<CashierNavTab> onTabChanged;

  const NavSidebar({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
  });

  @override
  State<NavSidebar> createState() => _NavSidebarState();
}

class _NavSidebarState extends State<NavSidebar> {
  late bool _isMenuExpanded;

  @override
  void initState() {
    super.initState();
    _isMenuExpanded = widget.currentTab == CashierNavTab.products ||
        widget.currentTab == CashierNavTab.categories;
  }

  @override
  void didUpdateWidget(covariant NavSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTab == CashierNavTab.products ||
        widget.currentTab == CashierNavTab.categories) {
      _isMenuExpanded = true;
    }
  }

  bool get isMenuCatalogActive =>
      widget.currentTab == CashierNavTab.products ||
      widget.currentTab == CashierNavTab.categories;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      decoration: const BoxDecoration(
        color: ColorTheme.cardBg,
        border: Border(right: BorderSide(color: ColorTheme.neutral300, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          const Text(
            'POS',
            style: TextStyle(
              color: ColorTheme.primary400,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const Text(
            'V1.0',
            style: TextStyle(
              color: ColorTheme.neutral500,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // ── Nav Items ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 1. Register / POS
                _NavItem(
                  tab: CashierNavTab.pos,
                  icon: Icons.point_of_sale_outlined,
                  activeIcon: Icons.point_of_sale,
                  label: 'Register',
                  isSelected: widget.currentTab == CashierNavTab.pos,
                  onTap: () => widget.onTabChanged(CashierNavTab.pos),
                ),

                // 2. Tables
                _NavItem(
                  tab: CashierNavTab.tables,
                  icon: Icons.table_restaurant_outlined,
                  activeIcon: Icons.table_restaurant,
                  label: 'Tables',
                  isSelected: widget.currentTab == CashierNavTab.tables,
                  onTap: () => widget.onTabChanged(CashierNavTab.tables),
                ),

                // 3. Menu Accordion with sleek sub-items
                _buildMenuAccordion(),

                // 4. Receipts History
                _NavItem(
                  tab: CashierNavTab.history,
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long,
                  label: 'History',
                  isSelected: widget.currentTab == CashierNavTab.history,
                  onTap: () => widget.onTabChanged(CashierNavTab.history),
                ),

                // 5. Analytics Dashboard
                _NavItem(
                  tab: CashierNavTab.dashboard,
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart,
                  label: 'Analytics',
                  isSelected: widget.currentTab == CashierNavTab.dashboard,
                  onTap: () => widget.onTabChanged(CashierNavTab.dashboard),
                ),
              ],
            ),
          ),

          // ── Settings pinned at bottom ───────────────────────────────────
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),
          _NavItem(
            tab: CashierNavTab.settings,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Setting',
            isSelected: widget.currentTab == CashierNavTab.settings,
            onTap: () => widget.onTabChanged(CashierNavTab.settings),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildMenuAccordion() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Menu Chip (Horizontal Row with Vibrant Blue Active State) ────
          InkWell(
            onTap: () {
              setState(() {
                _isMenuExpanded = !_isMenuExpanded;
              });
              if (_isMenuExpanded && !isMenuCatalogActive) {
                widget.onTabChanged(CashierNavTab.products);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
              decoration: BoxDecoration(
                color: isMenuCatalogActive
                    ? const Color(0xFF0D9488)
                    : (_isMenuExpanded ? const Color(0xFFF0FDFA) : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMenuCatalogActive
                      ? const Color(0xFF0D9488)
                      : (_isMenuExpanded ? const Color(0xFF99F6E4) : Colors.transparent),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isMenuCatalogActive
                          ? Colors.white
                          : (_isMenuExpanded ? const Color(0xFF0D9488) : const Color(0xFF334155)),
                    ),
                  ),
                  const SizedBox(width: 3),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isMenuExpanded ? 0.5 : 0.0,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: isMenuCatalogActive
                          ? Colors.white
                          : (_isMenuExpanded ? const Color(0xFF0D9488) : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Clean Sub-Items: Products & Category ───────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                _isMenuExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                children: [
                  // Sub-item 1: Products
                  _SubNavItem(
                    icon: Icons.inventory_2_outlined,
                    activeIcon: Icons.inventory_2,
                    label: 'Products',
                    isSelected: widget.currentTab == CashierNavTab.products,
                    onTap: () => widget.onTabChanged(CashierNavTab.products),
                  ),
                  const SizedBox(height: 4),
                  // Sub-item 2: Category
                  _SubNavItem(
                    icon: Icons.category_outlined,
                    activeIcon: Icons.category,
                    label: 'Category',
                    isSelected: widget.currentTab == CashierNavTab.categories,
                    onTap: () => widget.onTabChanged(CashierNavTab.categories),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Clean Sub-navigation item inside Menu (Horizontal Row Pill) ─────────────

class _SubNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual nav item ─────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final CashierNavTab tab;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0D9488) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 23,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
