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

class NavSidebar extends StatelessWidget {
  final CashierNavTab currentTab;
  final ValueChanged<CashierNavTab> onTabChanged;

  const NavSidebar({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
  });

  static const _mainItems = [
    (CashierNavTab.pos, Icons.point_of_sale_outlined, Icons.point_of_sale, 'Register'),
    (CashierNavTab.tables, Icons.table_restaurant_outlined, Icons.table_restaurant, 'Tables'),
    (CashierNavTab.products, Icons.inventory_2_outlined, Icons.inventory_2, 'Products'),
    (CashierNavTab.categories, Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Menu'),
    (CashierNavTab.history, Icons.receipt_long_outlined, Icons.receipt_long, 'History'),
    (CashierNavTab.dashboard, Icons.bar_chart_outlined, Icons.bar_chart, 'Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Column(
        children: [
          // ── Brand / Header ──────────────────────────────────────────────
          const SizedBox(height: 18),
          const Text(
            'POS',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const Text(
            'V1.0',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 8),

          // ── Nav Items ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _mainItems.map((item) {
                return _NavItem(
                  tab: item.$1,
                  icon: item.$2,
                  activeIcon: item.$3,
                  label: item.$4,
                  isSelected: currentTab == item.$1,
                  onTap: () => onTabChanged(item.$1),
                );
              }).toList(),
            ),
          ),

          // ── Settings pinned at bottom ───────────────────────────────────
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 4),
          _NavItem(
            tab: CashierNavTab.settings,
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings,
            label: 'Settings',
            isSelected: currentTab == CashierNavTab.settings,
            onTap: () => onTabChanged(CashierNavTab.settings),
          ),
          const SizedBox(height: 14),
        ],
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
            color: isSelected ? const Color(0xFFF1F5F9) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFFE2E8F0) : Colors.transparent,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    size: 20,
                    color: isSelected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                  ),
                  if (tab == CashierNavTab.categories)
                    Icon(
                      Icons.arrow_drop_down,
                      size: 14,
                      color: isSelected
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
