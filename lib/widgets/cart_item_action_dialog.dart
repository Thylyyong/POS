import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cart_controller.dart';
import '../core/theme/asset_theme.dart';
import 'app_svg_icon.dart';

class CartItemActionDialog extends StatefulWidget {
  final int itemIndex;
  final CartItem item;

  const CartItemActionDialog({
    super.key,
    required this.itemIndex,
    required this.item,
  });

  static Future<void> show(
    BuildContext context, {
    required int itemIndex,
    required CartItem item,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CartItemActionDialog(
        itemIndex: itemIndex,
        item: item,
      ),
    );
  }

  @override
  State<CartItemActionDialog> createState() => _CartItemActionDialogState();
}

class _CartItemActionDialogState extends State<CartItemActionDialog> {
  late int _quantity;
  late TextEditingController _priceCtrl;
  late TextEditingController _notesCtrl;
  String _inputMode = 'QTY'; // 'QTY' or 'PRICE'

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.quantity;
    _priceCtrl = TextEditingController(
      text: widget.item.unitPrice.toStringAsFixed(2),
    );
    _notesCtrl = TextEditingController(text: widget.item.notes ?? '');
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onNumpadDigit(String val) {
    if (_inputMode == 'QTY') {
      if (val == 'C') {
        setState(() => _quantity = 1);
      } else if (val == '⌫') {
        final s = '$_quantity';
        if (s.length > 1) {
          setState(() => _quantity = int.tryParse(s.substring(0, s.length - 1)) ?? 1);
        } else {
          setState(() => _quantity = 1);
        }
      } else {
        final digit = int.tryParse(val);
        if (digit != null) {
          final s = '$_quantity$val';
          final newQty = int.tryParse(s) ?? _quantity;
          if (newQty <= 999) {
            setState(() => _quantity = newQty);
          }
        }
      }
    } else {
      // Price input
      if (val == 'C') {
        setState(() => _priceCtrl.text = '0.00');
      } else if (val == '⌫') {
        if (_priceCtrl.text.isNotEmpty) {
          setState(() => _priceCtrl.text =
              _priceCtrl.text.substring(0, _priceCtrl.text.length - 1));
        }
      } else {
        setState(() => _priceCtrl.text += val);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartController>();
    final currency = cart.currencySymbol;
    final currentPrice = double.tryParse(_priceCtrl.text) ?? widget.item.unitPrice;
    final lineTotal = currentPrice * _quantity;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Line Total: $currency${lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const AppSvgIcon(
                      AssetTheme.close,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Mode Tabs: [ Quantity ] vs [ Override Price ]
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _inputMode = 'QTY'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _inputMode == 'QTY'
                              ? const Color(0xFF714B67)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Qty: $_quantity',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _inputMode == 'QTY'
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _inputMode = 'PRICE'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _inputMode == 'PRICE'
                              ? const Color(0xFF714B67)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Price: $currency${currentPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _inputMode == 'PRICE'
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Numpad (1-9, C, 0, Backspace)
              _buildNumpad(),
              const SizedBox(height: 12),

              // Notes Input Field
              TextField(
                controller: _notesCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Special instructions / item note...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  prefixIcon: const Icon(Icons.note_alt_outlined, size: 16, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),

              // Bottom Actions: [ Void Item ] & [ Apply Changes ]
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      backgroundColor: const Color(0xFFFEF2F2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      cart.removeItem(widget.itemIndex);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Void (0)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF714B67),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        // Apply Quantity
                        while (cart.items[widget.itemIndex].quantity < _quantity) {
                          cart.incrementQuantity(widget.itemIndex);
                        }
                        while (cart.items[widget.itemIndex].quantity > _quantity) {
                          cart.decrementQuantity(widget.itemIndex);
                        }
                        // Apply Price
                        if (currentPrice != widget.item.unitPrice) {
                          cart.updateItemPrice(widget.itemIndex, currentPrice);
                        }
                        // Apply Note
                        cart.updateItemNotes(widget.itemIndex, _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim());
                        Navigator.of(context).pop();
                      },
                      child: const Text('Update Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['C', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: row.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: key == 'C' || key == '⌫'
                            ? const Color(0xFFF1F5F9)
                            : Colors.white,
                        foregroundColor: key == 'C' || key == '⌫'
                            ? const Color(0xFF475569)
                            : const Color(0xFF0F172A),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => _onNumpadDigit(key),
                      child: Text(
                        key,
                        style: TextStyle(
                          fontSize: key == 'C' ? 13 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
