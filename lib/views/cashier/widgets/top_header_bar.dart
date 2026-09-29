import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app_config.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/register_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../core/debouncer.dart';
import '../../../core/device_profile.dart';
import '../../../core/theme/asset_theme.dart';
import '../../../services/presentation_service.dart';
import '../../../widgets/app_logo_widget.dart';
import '../../../widgets/app_svg_icon.dart';
import '../../../widgets/floating_customer_display_modal.dart';
import '../../../controllers/table_controller.dart';
import '../../advertising/advertising_screen.dart';
import '../../register/cash_in_out_dialog.dart';
import '../../register/close_register_dialog.dart';
import '../../register/open_register_dialog.dart';
import '../../settings/store_settings_screen.dart';
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
    final tableCtrl = context.watch<TableController>();
    final settings = context.select<SettingsController, dynamic>(
      (c) => c.settings,
    );

    final storeName = settings.storeName as String;
    final logoPath = settings.logoPath as String?;
    final autoPrint = context.select<SettingsController, bool>(
      (c) => c.settings.autoPrintOnPayment,
    );
    final cfdEnabled = context.select<SettingsController, bool>(
      (c) => c.settings.cfdEnabled,
    );
    final deviceProfile = context.select<SettingsController, String>(
      (c) => c.settings.deviceProfile,
    );
    final isKiosk = DeviceProfile.isKiosk(context, deviceProfile: deviceProfile);
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
          const SizedBox(width: 10),

          // ── User Role Badge ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                  size: 13,
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
                    fontSize: 10.5,
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
          const SizedBox(width: 8),

          // ── Register Status Pill (Open / Close Control) ────────────────
          InkWell(
            onTap: () {
              if (isSessionOpen) {
                CloseRegisterDialog.show(context);
              } else {
                OpenRegisterDialog.show(context);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSessionOpen
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
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
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSessionOpen
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isSessionOpen ? 'Register: OPEN' : 'Register: CLOSED',
                    style: TextStyle(
                      color: isSessionOpen
                          ? const Color(0xFF059669)
                          : const Color(0xFFDC2626),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Center: Search ────────────────────────────────────────────
          Flexible(
            fit: FlexFit.loose,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) {
                    _debouncer.call(() => posCtrl.setSearchQuery(val));
                    setState(() {});
                  },
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search menu...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 8, right: 5),
                      child: AppSvgIcon(
                        AssetTheme.search,
                        size: 16,
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
                              size: 12,
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
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
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
          const Spacer(),

          // ── 1. Odoo POS: Tables / Floor Plan Button (Compact) ─────────
          InkWell(
            onTap: () => widget.onNavigate?.call(CashierNavTab.tables),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.table_restaurant_rounded,
                    size: 13,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Tables',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: tableCtrl.occupiedCount > 0
                          ? const Color(0xFFEA580C)
                          : const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tableCtrl.occupiedCount > 0
                          ? '${tableCtrl.occupiedCount} Occ'
                          : '${tableCtrl.totalCount}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),

          // ── 2. Odoo POS: Orders / Receipts History Button (Compact) ───
          InkWell(
            onTap: () => widget.onNavigate?.call(CashierNavTab.history),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 13,
                    color: Color(0xFF475569),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Orders',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),

          // ── 3. Odoo POS: Screen Saver / Advertising Display Button ────
          InkWell(
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
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tv_rounded,
                    size: 13,
                    color: Color(0xFF0D9488),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Idle / Ads',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),

          // ── 4. Odoo POS: Owner / Admin Dashboard Button ───────────────
          if (auth.isOwner || auth.isAdminAuthenticated) ...[
            InkWell(
              onTap: () => widget.onNavigate?.call(CashierNavTab.dashboard),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.dashboard_customize_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),

            // ── 5. Odoo POS: Owner / Admin Settings Button ───────────────
            InkWell(
              onTap: () {
                if (widget.onNavigate != null) {
                  widget.onNavigate!(CashierNavTab.settings);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const StoreSettingsScreen(),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 13,
                      color: Color(0xFF334155),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
          ],

          // ── Cash In / Out Button (Compact) ────────────────────────────
          if (isSessionOpen) ...[
            InkWell(
              onTap: () => CashInOutDialog.show(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSvgIcon(
                      AssetTheme.wallet,
                      size: 13,
                      color: Color(0xFF475569),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Cash In/Out',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 5),
          ],

          // ── Kick Cash Drawer Direct Button (Compact) ──────────────────
          InkWell(
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
            borderRadius: BorderRadius.circular(6),
            child: Tooltip(
              message: 'Kick Cash Drawer Open (ESC/POS)',
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.point_of_sale_rounded,
                      size: 13,
                      color: Color(0xFF475569),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Kick Drawer',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),

          // ── Auto-Print Toggle Chip (Compact) ──────────────────────────
          InkWell(
            onTap: () {
              final newAutoPrint = !autoPrint;
              context.read<SettingsController>().toggleAutoPrint(newAutoPrint);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: autoPrint
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: autoPrint
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.print_outlined,
                    size: 13,
                    color: autoPrint
                        ? const Color(0xFF059669)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    autoPrint ? 'PRINT: ON' : 'PRINT: OFF',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: autoPrint
                          ? const Color(0xFF059669)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Dual-Screen / Duplicate Screen Button (Compact) ───────────
          if (!isKiosk && cfdEnabled) ...[
            const SizedBox(width: 5),
            InkWell(
              onTap: () async {
                final launched =
                    await PresentationService().launchSecondaryWindow();
                if (context.mounted) {
                  if (!launched) {
                    FloatingCustomerDisplayModal.show(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.devices_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Customer Display window opened on 2nd monitor!',
                            ),
                          ],
                        ),
                        action: SnackBarAction(
                          label: 'Preview Here',
                          textColor: AppConfig.accentCyan,
                          onPressed: () =>
                              FloatingCustomerDisplayModal.show(context),
                        ),
                        backgroundColor: const Color(0xFF0F172A),
                        duration: const Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.devices_rounded,
                      size: 13,
                      color: Color(0xFF0D9488),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Duplicate Screen',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
