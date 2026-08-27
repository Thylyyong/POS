import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/pos_controller.dart';
import '../../widgets/error_banner.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/receipt_history_screen.dart';
import '../products/category_screen.dart';
import '../products/product_list_screen.dart';
import '../settings/store_settings_screen.dart';
import '../tables/table_management_screen.dart';
import 'widgets/cart_panel.dart';
import 'widgets/item_grid.dart';
import 'widgets/nav_sidebar.dart';
import 'widgets/top_header_bar.dart';

class CashierMainLayout extends StatefulWidget {
  final CashierNavTab initialTab;
  const CashierMainLayout({super.key, this.initialTab = CashierNavTab.pos});

  @override
  State<CashierMainLayout> createState() => _CashierMainLayoutState();
}

class _CashierMainLayoutState extends State<CashierMainLayout> {
  late CashierNavTab _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  void _navigateToTab(CashierNavTab tab) {
    setState(() => _currentTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents accidentally popping root cashier screen
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Global error banners (settings + POS)
            _SettingsErrorBanner(),
            _PosErrorBanner(),

            Expanded(
              child: Row(
                children: [
                  // 1. Sidebar navigation rail
                  NavSidebar(
                    currentTab: _currentTab,
                    onTabChanged: (tab) => setState(() => _currentTab = tab),
                  ),

                  // 2. Main content area
                  Expanded(
                    child: Column(
                      children: [
                        // Store name + hardware status
                        const TopHeaderBar(),

                        // Body — animated cross-fade on tab switch
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(opacity: animation, child: child),
                            child: KeyedSubtree(
                              key: ValueKey(_currentTab),
                              child: _buildView(_currentTab),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildView(CashierNavTab tab) {
    switch (tab) {
      case CashierNavTab.pos:
        return Row(
          children: [
            const Expanded(child: ItemGrid()),
            CartPanel(
              onOpenTablePicker: () => _navigateToTab(CashierNavTab.tables),
            ),
          ],
        );
      case CashierNavTab.tables:
        return TableManagementScreen(
          onSwitchToPos: () => _navigateToTab(CashierNavTab.pos),
        );
      case CashierNavTab.products:
        return const ProductListScreen();
      case CashierNavTab.categories:
        return const CategoryScreen();
      case CashierNavTab.history:
        return const ReceiptHistoryScreen();
      case CashierNavTab.dashboard:
        return const DashboardScreen();
      case CashierNavTab.settings:
        return const StoreSettingsScreen();
    }
  }
}

// ── Error banner helpers — only rebuild when error string changes ──────────────

class _SettingsErrorBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final error = context.select<SettingsController, String?>(
      (c) => c.error,
    );
    if (error == null) return const SizedBox.shrink();
    return ErrorBanner(
      message: error,
      onDismiss: () => context.read<SettingsController>().clearError(),
    );
  }
}

class _PosErrorBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final error = context.select<PosController, String?>(
      (c) => c.error,
    );
    if (error == null) return const SizedBox.shrink();
    return ErrorBanner(
      message: error,
      onDismiss: () => context.read<PosController>().clearError(),
    );
  }
}
