import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/settings_controller.dart';
import 'cart_header.dart';
import 'cart_item_list.dart';
import 'cart_totals_panel.dart';

export 'cart_header.dart';
export 'cart_item_list.dart';
export 'cart_item_tile.dart';
export 'cart_totals_panel.dart';
export 'held_orders_modal.dart';

class CartPanel extends StatelessWidget {
  final VoidCallback? onOpenTablePicker;

  const CartPanel({super.key, this.onOpenTablePicker});

  @override
  Widget build(BuildContext context) {
    final currency = context.select<SettingsController, String>(
      (c) => c.settings.currencySymbol,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
      ),
      child: Column(
        children: [
          CartHeader(currency: currency, onOpenTablePicker: onOpenTablePicker),
          const Expanded(child: CartItemList()),
          CartTotalsPanel(currency: currency),
        ],
      ),
    );
  }
}
