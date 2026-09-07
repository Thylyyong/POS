import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_config.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/register_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../core/debouncer.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../services/presentation_service.dart';
import '../../../widgets/app_logo_widget.dart';
import '../../../widgets/app_svg_icon.dart';
import '../../register/cash_in_out_dialog.dart';
import '../../register/close_register_dialog.dart';
import '../../register/open_register_dialog.dart';
import 'nav_sidebar.dart';

/// POS Top Header Bar with Register status, Role badge, and Drawer controls.
class TopHeaderBar extends StatefulWidget {
  final ValueChanged<CashierNavTab>? onNavigate;
  const TopHeaderBar({super.key, this.onNavigate});

  @override
  State<TopHeaderBar> createState() => _TopHeaderBarState();
}

class _TopHeaderBarState extends State<TopHeaderBar> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _debouncer = Debouncer(
    duration: const Duration(milliseconds: 280),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      context.read<RegisterController>().loadActiveSession(
        branchId: auth.currentBranchId,
      );
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.read<PosController>();
    final auth = context.watch<AuthController>();
    final register = context.watch<RegisterController>();
    final settings = context.select<SettingsController, dynamic>(
      (c) => c.settings,
    );

    final storeName = settings.storeName as String;
    final logoPath = settings.logoPath as String?;
    final autoPrint = context.select<SettingsController, bool>(
      (c) => c.settings.autoPrintOnPayment,
    );
    final isSessionOpen = register.isSessionOpen;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // ── Nav menu button ───────────────────────────────────────────
          if (widget.onNavigate != null)
            _NavMenuButton(onNavigate: widget.onNavigate!),
          const SizedBox(width: 8),

          // ── Left: Logo + Store Name ───────────────────────────────────
          AppLogoWidget(
            logoPath: logoPath,
            size: 32,
            borderRadius: 8,
            fallbackSvg: AssetTheme.store,
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                storeName,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                auth.currentBranchName,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // ── User Role Badge ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: auth.isMainBoss
                  ? const Color(0xFFFAF5FF)
                  : (auth.isSubBoss
                        ? const Color(0xFFF0F9FF)
                        : const Color(0xFFFFF7ED)),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: auth.isMainBoss
                    ? const Color(0xFFD8B4FE)
                    : (auth.isSubBoss
                          ? const Color(0xFFBAE6FD)
                          : const Color(0xFFFFEDD5)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppSvgIcon(
                  auth.isMainBoss
                      ? AssetTheme.verify
                      : (auth.isSubBoss ? AssetTheme.store : AssetTheme.user),
                  size: 15,
                  color: auth.isMainBoss
                      ? const Color(0xFF7C3AED)
                      : (auth.isSubBoss
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFEA580C)),
                ),
                const SizedBox(width: 4),
                Text(
                  auth.currentUser.displayName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: auth.isMainBoss
                        ? const Color(0xFF7C3AED)
                        : (auth.isSubBoss
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFEA580C)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Register Status Pill (Open / Close Control) ────────────────
          InkWell(
            onTap: () {
              if (isSessionOpen) {
                CloseRegisterDialog.show(context);
              } else {
                OpenRegisterDialog.show(context);
              }
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSessionOpen
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSessionOpen
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSessionOpen
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isSessionOpen ? 'Register: OPEN' : 'Register: CLOSED',
                    style: TextStyle(
                      color: isSessionOpen
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          // ── Center: Search ────────────────────────────────────────────
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    _debouncer.call(() => posCtrl.setSearchQuery(val));
                    setState(() {});
                  },
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search menu items...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12.5,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 10, right: 6),
                      child: AppSvgIcon(
                        AssetTheme.search,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const AppSvgIcon(
                              AssetTheme.close,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            onPressed: () {
                              _searchCtrl.clear();
                              _debouncer.cancel();
                              posCtrl.clearSearch();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    fillColor: const Color(0xFFF1F5F9),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF0F172A),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Cash In / Out Button ──────────────────────────────────────
          if (isSessionOpen) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF8FAFC),
                foregroundColor: const Color(0xFF334155),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => CashInOutDialog.show(context),
              icon: const AppSvgIcon(
                AssetTheme.wallet,
                size: 16,
                color: Color(0xFF475569),
              ),
              label: const Text(
                'Cash In/Out',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // ── Kick Cash Drawer Direct Button ────────────────────────────
          _HeaderIcon(
            icon: Icons.point_of_sale_outlined,
            tooltip: 'Kick Cash Drawer Open (ESC/POS)',
            active: true,
            activeColor: const Color(0xFF64748B),
            onTap: () async {
              await register.kickDrawerDirectly();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cash drawer kick pulse sent!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          const SizedBox(width: 4),

          // ── Auto-Print Toggle ─────────────────────────────────────────
          _HeaderIcon(
            icon: autoPrint ? Icons.print : Icons.print_disabled_outlined,
            tooltip: autoPrint
                ? 'Receipt Auto-Print: ON'
                : 'Receipt Auto-Print: OFF',
            active: autoPrint,
            activeColor: const Color(0xFF10B981),
            onTap: () {
              final newAutoPrint = !autoPrint;
              context.read<SettingsController>().toggleAutoPrint(newAutoPrint);
            },
          ),
          const SizedBox(width: 4),

          // ── CFD Dual-Screen Button ────────────────────────────────────
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () async {
              await PresentationService().launchSecondaryWindow();
            },
            icon: const Icon(
              Icons.screen_share_outlined,
              size: 16,
              color: Color(0xFF0F172A),
            ),
            label: const Text(
              'Dual Screen',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final Color activeColor;
  final VoidCallback? onTap;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    this.active = false,
    this.activeColor = AppConfig.accentGreen,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: active ? activeColor : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _NavMenuButton extends StatelessWidget {
  final ValueChanged<CashierNavTab> onNavigate;

  const _NavMenuButton({required this.onNavigate});

  static const _items = [
    (CashierNavTab.pos, Icons.point_of_sale_outlined, 'POS Register'),
    (CashierNavTab.tables, Icons.table_restaurant_outlined, 'Tables'),
    (CashierNavTab.products, Icons.inventory_2_outlined, 'Products Catalog'),
    (CashierNavTab.categories, Icons.menu_book_outlined, 'Menu Categories'),
    (CashierNavTab.history, Icons.receipt_long_outlined, 'Receipts History'),
    (
      CashierNavTab.accounting,
      Icons.account_balance_outlined,
      'Odoo P&L Accounting',
    ),
    (CashierNavTab.dashboard, Icons.analytics_outlined, 'Analytics Dashboard'),
    (CashierNavTab.settings, Icons.settings_outlined, 'Hardware & Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CashierNavTab>(
      tooltip: 'Navigate Modules',
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      onSelected: onNavigate,
      itemBuilder: (_) => _items.map((item) {
        return PopupMenuItem<CashierNavTab>(
          value: item.$1,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(item.$2, size: 20, color: const Color(0xFF64748B)),
              const SizedBox(width: 12),
              Text(
                item.$3,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.apps_rounded,
          size: 22,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}
