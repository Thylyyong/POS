import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/settings_controller.dart';
import '../../../core/debouncer.dart';
import '../../../services/presentation_service.dart';
import '../../../widgets/app_logo_widget.dart';
import '../../customer_display/customer_main_view.dart';
import 'nav_sidebar.dart';

/// POS-only top header bar.
/// Layout: [NavMenu | Logo + Store Name] · [Search — grows] · [Status Icons + Duplicate btn]
class TopHeaderBar extends StatefulWidget {
  final ValueChanged<CashierNavTab>? onNavigate;
  const TopHeaderBar({super.key, this.onNavigate});

  @override
  State<TopHeaderBar> createState() => _TopHeaderBarState();
}

class _TopHeaderBarState extends State<TopHeaderBar> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Debouncer _debouncer =
      Debouncer(duration: const Duration(milliseconds: 280));

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debouncer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.read<PosController>();
    final settings = context.select<SettingsController, dynamic>(
      (c) => c.settings,
    );
    final storeName = settings.storeName as String;
    final logoPath = settings.logoPath as String?;
    final cfdEnabled = context.select<SettingsController, bool>(
      (c) => c.settings.cfdEnabled,
    );
    final is80mm = context.select<SettingsController, bool>(
      (c) => c.settings.isPaperSize80mm,
    );

    return Container(
      height: 56,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // ── Nav menu button ───────────────────────────────────────────
          if (widget.onNavigate != null)
            _NavMenuButton(onNavigate: widget.onNavigate!),
          const SizedBox(width: 8),

          // ── Left: logo + store name ───────────────────────────────────
          AppLogoWidget(
            logoPath: logoPath,
            size: 30,
            borderRadius: 8,
            fallbackIcon: Icons.point_of_sale,
          ),
          const SizedBox(width: 8),
          Text(
            storeName,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 16),

          // ── Center: search ────────────────────────────────────────────
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) {
                  _debouncer.call(() => posCtrl.setSearchQuery(val));
                  setState(() {}); // rebuild for suffix icon
                },
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Search menu items...',
                  hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 10, right: 6),
                    child: Icon(Icons.search,
                        size: 18, color: Color(0xFF94A3B8)),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Color(0xFF94A3B8)),
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
                        color: Color(0xFF0F172A), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Right: status icons ───────────────────────────────────────
         
          _HeaderIcon(
            icon: Icons.print_outlined,
            tooltip: is80mm ? '80mm Thermal' : '58mm Thermal',
            active: false,
          ),
          _HeaderIcon(
            icon: Icons.tv_outlined,
            tooltip: cfdEnabled ? 'CFD Active' : 'CFD Off',
            active: cfdEnabled,
            activeColor: const Color(0xFF2563EB),
            onTap: () async {
              await PresentationService().showCustomerDisplay();
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CustomerMainView()),
                );
              }
            },
          ),
          const SizedBox(width: 8),

          // ── Duplicate Screen button ────────────────────────────────────
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () async {
              await PresentationService().showCustomerDisplay();
              if (context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const CustomerMainView()),
                );
              }
            },
            icon: const Icon(Icons.screen_share_outlined, size: 15, color: Color(0xFF0F172A)),
            label: const Text(
              'Duplicate',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small header icon button ────────────────────────────────────────────────

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
          padding: const EdgeInsets.all(7),
          child: Icon(
            icon,
            size: 20,
            color: active ? activeColor : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }
}

// ── Navigation popup menu button (POS top bar) ──────────────────────────────

class _NavMenuButton extends StatelessWidget {
  final ValueChanged<CashierNavTab> onNavigate;

  const _NavMenuButton({required this.onNavigate});

  static const _items = [
    (CashierNavTab.tables,    Icons.table_restaurant_outlined, 'Tables'),
    (CashierNavTab.products,  Icons.inventory_2_outlined,      'Products'),
    (CashierNavTab.categories,Icons.menu_book_outlined,        'Menu'),
    (CashierNavTab.history,   Icons.receipt_long_outlined,     'Receipts'),
    (CashierNavTab.dashboard, Icons.analytics_outlined,        'Analytics'),
    (CashierNavTab.settings,  Icons.settings_outlined,         'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CashierNavTab>(
      tooltip: 'Navigate',
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
              Icon(item.$2, size: 18, color: const Color(0xFF64748B)),
              const SizedBox(width: 12),
              Text(
                item.$3,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.apps_rounded,
          size: 20,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}
