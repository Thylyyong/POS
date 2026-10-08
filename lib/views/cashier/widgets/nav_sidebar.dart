import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_config.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../core/theme/sprite_icons.dart';
import '../../../widgets/app_logo_widget.dart';
import '../../../widgets/app_svg_icon.dart';
import '../../portal/owner_portal_screen.dart';
import '../../advertising/advertising_screen.dart';

enum CashierNavTab {
  pos,
  tables,
  products,
  categories,
  history,
  accounting,
  dashboard,
  staff,
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
    _isMenuExpanded =
        widget.currentTab == CashierNavTab.products ||
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
    final auth = context.watch<AuthController>();
    final isOwner = auth.isOwner || auth.isMainBoss || auth.isSubBoss;
    final storeName = context.select<SettingsController, String>(
      (controller) => controller.settings.storeName,
    );
    final logoPath = context.select<SettingsController, String?>(
      (controller) => controller.settings.logoPath,
    );

    return Container(
      width: 128,
      decoration: const BoxDecoration(
        color: ColorTheme.cardBg,
        border: Border(
          right: BorderSide(color: ColorTheme.neutral300, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          AppLogoWidget(logoPath: logoPath, size: 34, borderRadius: 8),
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              storeName.trim().isEmpty ? 'Store' : storeName.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ColorTheme.primary500,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              auth.currentBranchName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ColorTheme.neutral500,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 6),

          // ── Nav Items (ALL TABS FOR BOSS) ─────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // 1. Dashboard (Shown for Boss / Owner)
                if (isOwner)
                  _NavItem(
                    tab: CashierNavTab.dashboard,
                    iconData: Icons.dashboard_customize_rounded,
                    label: 'Dashboard',
                    isSelected: widget.currentTab == CashierNavTab.dashboard,
                    onTap: () => widget.onTabChanged(CashierNavTab.dashboard),
                  ),

                // 2. POS
                _NavItem(
                  tab: CashierNavTab.pos,
                  spriteIcon: SpriteIcons.pos,
                  label: 'POS',
                  isSelected: widget.currentTab == CashierNavTab.pos,
                  onTap: () => widget.onTabChanged(CashierNavTab.pos),
                ),

                // 3. Tables
                _NavItem(
                  tab: CashierNavTab.tables,
                  spriteIcon: SpriteIcons.table,
                  label: 'Tables',
                  isSelected: widget.currentTab == CashierNavTab.tables,
                  onTap: () => widget.onTabChanged(CashierNavTab.tables),
                ),

                // 4. Menu Accordion with sleek sub-items
                _buildMenuAccordion(),

                // 5. Receipts History
                _NavItem(
                  tab: CashierNavTab.history,
                  spriteIcon: SpriteIcons.history,
                  label: 'History',
                  isSelected: widget.currentTab == CashierNavTab.history,
                  onTap: () => widget.onTabChanged(CashierNavTab.history),
                ),

                // 6. Accounting (P&L Reports - Shown for Boss / Owner)
                if (isOwner)
                  _NavItem(
                    tab: CashierNavTab.accounting,
                    iconData: Icons.account_balance_rounded,
                    label: 'Accounting',
                    isSelected: widget.currentTab == CashierNavTab.accounting,
                    onTap: () => widget.onTabChanged(CashierNavTab.accounting),
                  ),

                // 7. Staff Management (Owner only)
                if (isOwner)
                  _NavItem(
                    tab: CashierNavTab.staff,
                    iconData: Icons.people_alt_rounded,
                    label: 'Staff',
                    isSelected: widget.currentTab == CashierNavTab.staff,
                    onTap: () => widget.onTabChanged(CashierNavTab.staff),
                  ),

                // 8. Hardware & Settings
                _NavItem(
                  tab: CashierNavTab.settings,
                  spriteIcon: SpriteIcons.settings,
                  label: 'Settings',
                  isSelected: widget.currentTab == CashierNavTab.settings,
                  onTap: () => widget.onTabChanged(CashierNavTab.settings),
                ),
              ],
            ),
          ),

          // ── Bottom Quick Navigation ───────────────────────────────────
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 4),
          if (isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 300),
                      pageBuilder: (_, _, _) => const OwnerPortalScreen(),
                      transitionsBuilder: (_, animation, _, child) =>
                          FadeTransition(opacity: animation, child: child),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.apps_rounded,
                        size: 16,
                        color: Color(0xFF0F172A),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Portal',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: InkWell(
              onTap: () {
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 300),
                    pageBuilder: (_, _, _) => const AdvertisingScreen(),
                    transitionsBuilder: (_, animation, _, child) =>
                        FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tv_rounded, size: 16, color: Color(0xFF64748B)),
                    SizedBox(height: 2),
                    Text(
                      'Idle / Ads',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMenuAccordion() {
    final isMenuSelected = isMenuCatalogActive;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Menu Chip ────
          InkWell(
            onTap: () {
              setState(() {
                _isMenuExpanded = !_isMenuExpanded;
              });
              if (_isMenuExpanded && !isMenuCatalogActive) {
                widget.onTabChanged(CashierNavTab.products);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeInOut,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: isMenuSelected
                    ? const Color(0xFF0D9488)
                    : (_isMenuExpanded
                          ? const Color(0xFFF0FDFA)
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isMenuSelected
                      ? const Color(0xFF0D9488)
                      : (_isMenuExpanded
                            ? const Color(0xFF99F6E4)
                            : Colors.transparent),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppSvgIcon.sprite(
                    SpriteIcons.menu,
                    size: 20,
                    color: isMenuSelected
                        ? Colors.white
                        : (_isMenuExpanded
                              ? const Color(0xFF0D9488)
                              : const Color(0xFF475569)),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: (isMenuSelected || _isMenuExpanded)
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: isMenuSelected
                              ? Colors.white
                              : (_isMenuExpanded
                                    ? const Color(0xFF0D9488)
                                    : const Color(0xFF334155)),
                          letterSpacing: 0.2,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Clean Sub-Items: Products & Category ───────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _isMenuExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                children: [
                  // Sub-item 1: Products
                  _SubNavItem(
                    spriteIcon: SpriteIcons.products,
                    label: 'Products',
                    isSelected: widget.currentTab == CashierNavTab.products,
                    onTap: () => widget.onTabChanged(CashierNavTab.products),
                  ),
                  const SizedBox(height: 4),
                  // Sub-item 2: Category
                  _SubNavItem(
                    spriteIcon: SpriteIcons.categories,
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

class _SubNavItem extends StatelessWidget {
  final String spriteIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubNavItem({
    required this.spriteIcon,
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
            color: isSelected
                ? const Color(0xFF0D9488)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSvgIcon.sprite(
              spriteIcon,
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

class _NavItem extends StatelessWidget {
  final CashierNavTab tab;
  final String? spriteIcon;
  final IconData? iconData;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    this.spriteIcon,
    this.iconData,
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
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0D9488) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (spriteIcon != null)
                AppSvgIcon.sprite(
                  spriteIcon!,
                  size: 20,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                )
              else if (iconData != null)
                Icon(
                  iconData,
                  size: 20,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  letterSpacing: 0.2,
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
