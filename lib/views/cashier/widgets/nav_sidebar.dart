import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/settings_controller.dart';
import '../../../services/presentation_service.dart';
import '../../../widgets/app_logo_widget.dart';
import '../../customer_display/customer_main_view.dart';

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

  static const _navItems = [
    (CashierNavTab.pos, Icons.shopping_basket_outlined, Icons.shopping_basket, 'POS'),
    (CashierNavTab.tables, Icons.table_restaurant_outlined, Icons.table_restaurant, 'Tables'),
    (CashierNavTab.products, Icons.inventory_2_outlined, Icons.inventory_2, 'Items'),
    (CashierNavTab.categories, Icons.category_outlined, Icons.category, 'Menu'),
    (CashierNavTab.history, Icons.receipt_long_outlined, Icons.receipt_long, 'Receipts'),
    (CashierNavTab.dashboard, Icons.analytics_outlined, Icons.analytics, 'Analytics'),
    (CashierNavTab.settings, Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate-900
        border: Border(right: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildLogo(context),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...NavSidebar._navItems.map(
                  (item) => _NavItem(
                    tab: item.$1,
                    icon: item.$2,
                    activeIcon: item.$3,
                    label: item.$4,
                    isSelected: currentTab == item.$1,
                    onTap: () => onTabChanged(item.$1),
                  ),
                ),
              ],
            ),
          ),
          _buildCfdPreviewButton(context),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final logoPath = context.select<SettingsController, String?>(
      (c) => c.settings.logoPath,
    );
    return AppLogoWidget(
      logoPath: logoPath,
      size: 48,
      borderRadius: 14,
      fallbackIcon: Icons.point_of_sale,
    );
  }

  Widget _buildCfdPreviewButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.screen_share, color: AppConfig.accentCyan, size: 22),
      tooltip: 'Duplicate / Customer Facing Display (CFD)',
      onPressed: () async {
        await PresentationService().showCustomerDisplay();
        if (context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CustomerMainView()),
          );
        }
      },
    );
  }
}

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
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected
              ? AppConfig.accentGreen.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppConfig.accentGreen : Colors.transparent,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppConfig.accentGreen : const Color(0xFF94A3B8),
                  size: 22,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
