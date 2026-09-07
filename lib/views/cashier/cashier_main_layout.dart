import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/pos_controller.dart';
import '../../widgets/admin_pin_dialog.dart';
import '../../widgets/error_banner.dart';
import '../accounting/profit_loss_screen.dart';
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

  Future<void> _navigateToTab(CashierNavTab tab) async {
    final isAdminTab =
        tab == CashierNavTab.dashboard ||
        tab == CashierNavTab.settings ||
        tab == CashierNavTab.accounting;

    if (isAdminTab) {
      final authCtrl = context.read<AuthController>();
      if (!authCtrl.isAdminAuthenticated) {
        final verified = await AdminPinDialog.show(
          context,
          title: 'Admin Verification',
          subtitle: 'Enter master PIN code to unlock Admin section',
        );
        if (!verified || !mounted) return;
      }
    }

    if (mounted) {
      setState(() => _currentTab = tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPosTab = _currentTab == CashierNavTab.pos;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // Global error banners
            _SettingsErrorBanner(),
            _PosErrorBanner(),

            Expanded(
              child: isPosTab
                  // ── POS tab: no sidebar, top bar + full-width cashier layout ──
                  ? Column(
                      children: [
                        TopHeaderBar(onNavigate: _navigateToTab),
                        Expanded(
                          child: Row(
                            children: [
                              const Expanded(flex: 70, child: ItemGrid()),
                              Expanded(
                                flex: 30,
                                child: CartPanel(
                                  onOpenTablePicker: () =>
                                      _navigateToTab(CashierNavTab.tables),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  // ── Other tabs: light sidebar + sub-screen ─────────────────
                  : Row(
                      children: [
                        NavSidebar(
                          currentTab: _currentTab,
                          onTabChanged: _navigateToTab,
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
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
    );
  }

  Widget _buildView(CashierNavTab tab) {
    switch (tab) {
      case CashierNavTab.pos:
        // This case is handled above; won't be reached normally
        return const SizedBox.shrink();
      case CashierNavTab.tables:
        return TableManagementScreen(
          onSwitchToPos: () => _navigateToTab(CashierNavTab.pos),
        );
      case CashierNavTab.products:
        return const ProductListScreen();
      case CashierNavTab.categories:
        return const CategoryScreen();
      case CashierNavTab.history:
        return ReceiptHistoryScreen(
          onSwitchToPos: () => _navigateToTab(CashierNavTab.pos),
        );
      case CashierNavTab.accounting:
        return const ProfitLossScreen();
      case CashierNavTab.dashboard:
        return const DashboardScreen();
      case CashierNavTab.settings:
        return const StoreSettingsScreen();
    }
  }
}

// ── Error banner helpers ────────────────────────────────────────────────────

class _SettingsErrorBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final error = context.select<SettingsController, String?>((c) => c.error);
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
    final error = context.select<PosController, String?>((c) => c.error);
    if (error == null) return const SizedBox.shrink();
    return ErrorBanner(
      message: error,
      onDismiss: () => context.read<PosController>().clearError(),
    );
  }
}
