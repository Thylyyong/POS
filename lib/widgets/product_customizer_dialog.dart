import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cart_controller.dart';
import '../core/theme/asset_theme.dart';
import '../models/product_model.dart';
import 'app_svg_icon.dart';

class ProductCustomizerDialog extends StatefulWidget {
  final Product product;

  const ProductCustomizerDialog({super.key, required this.product});

  static Future<void> show(BuildContext context, Product product) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ProductCustomizerDialog(product: product),
    );
  }

  @override
  State<ProductCustomizerDialog> createState() =>
      _ProductCustomizerDialogState();
}

class _ProductCustomizerDialogState extends State<ProductCustomizerDialog> {
  int _quantity = 1;

  // Drink defaults
  String _size = 'Regular';
  String _temperature = 'Iced';
  String _sweetness = '100%';
  String _ice = 'Normal Ice';

  // Food defaults
  String _spice = 'Medium';
  String _portion = 'Regular';

  // Add-ons selection (multi-choice)
  final Set<String> _selectedAddOns = {};

  final Map<String, double> _addOnPrices = {
    'Boba Pearls': 0.50,
    'Grass Jelly': 0.50,
    'Cheese Foam': 0.75,
    'Extra Shot': 0.75,
    'Extra Cheese': 0.75,
    'Extra Sauce': 0.50,
    'Fried Egg': 0.75,
  };

  bool get _isDrink {
    final cat = widget.product.categoryId.toLowerCase();
    final name = widget.product.name.toLowerCase();
    return cat.contains('drink') ||
        cat.contains('beverage') ||
        name.contains('coffee') ||
        name.contains('tea') ||
        name.contains('smoothie') ||
        name.contains('juice') ||
        name.contains('frappe') ||
        name.contains('latte');
  }

  double get _unitPrice {
    double price = widget.product.price;
    if (_size == 'Large' || _portion == 'Extra Large') {
      price += (_isDrink ? 0.50 : 1.50);
    }
    for (final addOn in _selectedAddOns) {
      price += _addOnPrices[addOn] ?? 0.0;
    }
    return price;
  }

  double get _totalPrice => _unitPrice * _quantity;

  String _buildNotes() {
    final parts = <String>[];
    if (_isDrink) {
      parts.add(_size);
      parts.add(_temperature);
      parts.add('$_sweetness Sweet');
      if (_temperature == 'Iced') parts.add(_ice);
    } else {
      parts.add('$_portion Portion');
      parts.add('$_spice Spicy');
    }
    if (_selectedAddOns.isNotEmpty) {
      parts.add('Add: ${_selectedAddOns.join(', ')}');
    }
    return '[${parts.join(' • ')}]';
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final currency = context.watch<CartController>().currencySymbol;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Icon(
                        _isDrink
                            ? Icons.local_cafe_rounded
                            : Icons.restaurant_rounded,
                        size: 24,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Base Price: $currency${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
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
              const Divider(height: 24),

              // Options list
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isDrink) ...[
                        // Cup Size
                        _buildSectionHeader('Cup Size'),
                        _buildChoiceChips(
                          options: ['Regular', 'Large (+\$0.50)'],
                          selected: _size.startsWith('Large')
                              ? 'Large (+\$0.50)'
                              : 'Regular',
                          onSelected: (val) {
                            setState(() {
                              _size = val.startsWith('Large')
                                  ? 'Large'
                                  : 'Regular';
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // Temperature
                        _buildSectionHeader('Serving Temperature'),
                        _buildChoiceChips(
                          options: ['Iced', 'Hot'],
                          selected: _temperature,
                          onSelected: (val) =>
                              setState(() => _temperature = val),
                        ),
                        const SizedBox(height: 14),

                        // Sweetness Level
                        _buildSectionHeader('Sweetness Level'),
                        _buildChoiceChips(
                          options: [
                            '100% (Normal)',
                            '50% (Half)',
                            '30% (Less)',
                            '0% (No Sugar)',
                          ],
                          selected: _sweetness == '100%'
                              ? '100% (Normal)'
                              : (_sweetness == '50%'
                                    ? '50% (Half)'
                                    : (_sweetness == '30%'
                                          ? '30% (Less)'
                                          : '0% (No Sugar)')),
                          onSelected: (val) {
                            setState(() {
                              _sweetness = val.split(' ').first;
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // Ice Level (only if Iced)
                        if (_temperature == 'Iced') ...[
                          _buildSectionHeader('Ice Level'),
                          _buildChoiceChips(
                            options: ['Normal Ice', 'Less Ice', 'No Ice'],
                            selected: _ice,
                            onSelected: (val) => setState(() => _ice = val),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Add-ons
                        _buildSectionHeader('Extra Add-ons (Multi-Choice)'),
                        _buildAddOnChips([
                          'Boba Pearls',
                          'Grass Jelly',
                          'Cheese Foam',
                          'Extra Shot',
                        ]),
                      ] else ...[
                        // Food: Spice Level
                        _buildSectionHeader('Spice Level'),
                        _buildChoiceChips(
                          options: ['Mild', 'Medium', 'Hot', 'Extra Spicy'],
                          selected: _spice,
                          onSelected: (val) => setState(() => _spice = val),
                        ),
                        const SizedBox(height: 14),

                        // Portion
                        _buildSectionHeader('Portion Size'),
                        _buildChoiceChips(
                          options: ['Regular', 'Extra Large (+\$1.50)'],
                          selected: _portion.startsWith('Extra')
                              ? 'Extra Large (+\$1.50)'
                              : 'Regular',
                          onSelected: (val) {
                            setState(() {
                              _portion = val.startsWith('Extra')
                                  ? 'Extra Large'
                                  : 'Regular';
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // Food Add-ons
                        _buildSectionHeader('Extra Add-ons (Multi-Choice)'),
                        _buildAddOnChips([
                          'Extra Cheese',
                          'Extra Sauce',
                          'Fried Egg',
                        ]),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 20),

              // Bottom Bar: Quantity Stepper & Add to Cart CTA
              Row(
                children: [
                  // Quantity Stepper
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Container(
                          width: 32,
                          alignment: Alignment.center,
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        IconButton(
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Add to Cart Button
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF714B67,
                        ), // Odoo Aubergine
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        final notes = _buildNotes();
                        final customPrice = _unitPrice;
                        context.read<CartController>().addProduct(
                          widget.product,
                          quantity: _quantity,
                          notes: notes,
                          customUnitPrice: customPrice,
                        );
                        Navigator.of(context).pop();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Add to Order • $currency${_totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildChoiceChips({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return ChoiceChip(
          label: Text(
            opt,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
          selected: isSelected,
          selectedColor: const Color(0xFF714B67),
          backgroundColor: const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF714B67)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          onSelected: (_) => onSelected(opt),
        );
      }).toList(),
    );
  }

  Widget _buildAddOnChips(List<String> addOns) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: addOns.map((addOn) {
        final isSelected = _selectedAddOns.contains(addOn);
        final price = _addOnPrices[addOn] ?? 0.0;
        final label = '$addOn (+\$${price.toStringAsFixed(2)})';

        return FilterChip(
          label: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : const Color(0xFF334155),
            ),
          ),
          selected: isSelected,
          selectedColor: const Color(0xFF059669),
          backgroundColor: const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF059669)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedAddOns.add(addOn);
              } else {
                _selectedAddOns.remove(addOn);
              }
            });
          },
        );
      }).toList(),
    );
  }
}
