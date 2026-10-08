import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/cart_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/register_controller.dart';
import '../views/register/open_register_dialog.dart';
import '../core/product_image_helper.dart';
import '../models/product_model.dart';
import '../models/product_variant_model.dart';

class ProductVariantDialog extends StatefulWidget {
  final Product product;

  const ProductVariantDialog({
    super.key,
    required this.product,
  });

  static Future<bool> show(
    BuildContext context, {
    required Product product,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ProductVariantDialog(product: product),
    );
    return result ?? false;
  }

  @override
  State<ProductVariantDialog> createState() => _ProductVariantDialogState();
}

class _ProductVariantDialogState extends State<ProductVariantDialog> {
  late ProductVariantConfig _config;

  // Selected values
  String _sugarLevel = 'Normal Sugar (100%)';
  String _iceLevel = 'Normal Ice';
  String _spicyLevel = 'Normal Spicy';
  final Map<String, String> _selectedCustomOptions = {};
  final Set<String> _selectedAddonIds = {};
  int _quantity = 1;
  final TextEditingController _notesCtrl = TextEditingController();

  static const List<String> _sugarOptions = [
    'Normal Sugar (100%)',
    'Less Sugar (50%)',
    'No Sugar (0%)',
  ];

  static const List<String> _iceOptions = [
    'Normal Ice',
    'Less Ice',
    'No Ice',
  ];

  static const List<String> _spicyOptions = [
    'Not Spicy',
    'Normal Spicy',
    'Extra Spicy 🔥',
  ];

  @override
  void initState() {
    super.initState();
    _config = widget.product.variantConfig;
    for (final grp in _config.customGroups) {
      if (grp.options.isNotEmpty) {
        _selectedCustomOptions[grp.id] = grp.defaultOption ?? grp.options.first;
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _addonsTotalPerUnit {
    double sum = 0.0;
    for (final addon in _config.addons) {
      if (_selectedAddonIds.contains(addon.id)) {
        sum += addon.price;
      }
    }
    return sum;
  }

  double get _unitPrice => widget.product.price + _addonsTotalPerUnit;
  double get _lineTotal => _unitPrice * _quantity;

  String _buildNotesSummary() {
    final List<String> parts = [];

    for (final grp in _config.customGroups) {
      final selected = _selectedCustomOptions[grp.id];
      if (selected != null && selected.isNotEmpty) {
        parts.add('${grp.name}: $selected');
      }
    }

    if (_config.hasSugar) {
      parts.add(_sugarLevel);
    }
    if (_config.hasIce) {
      parts.add(_iceLevel);
    }
    if (_config.hasSpicy) {
      parts.add(_spicyLevel);
    }
    for (final addon in _config.addons) {
      if (_selectedAddonIds.contains(addon.id)) {
        parts.add('${addon.name} (+${addon.price.toStringAsFixed(2)})');
      }
    }

    final userNote = _notesCtrl.text.trim();
    if (userNote.isNotEmpty) {
      parts.add('Note: $userNote');
    }

    return parts.join(', ');
  }

  void _onConfirm() {
    final register = context.read<RegisterController>();
    if (!register.isSessionOpen) {
      Navigator.of(context).pop(false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Register is closed. Can't order — please open register first."),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 3),
        ),
      );
      OpenRegisterDialog.show(context);
      return;
    }

    final cart = context.read<CartController>();
    final notes = _buildNotesSummary();
    final customPrice = _unitPrice;

    final added = cart.addProduct(
      widget.product,
      quantity: _quantity,
      customUnitPrice: customPrice,
      notes: notes.isNotEmpty ? notes : null,
    );

    if (added) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.product.stockQuantity <= 0
                ? '${widget.product.name} is OUT OF STOCK'
                : 'Cannot add more. Only ${widget.product.stockQuantity} in stock.',
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.select<SettingsController, String>(
      (c) => c.settings.currencySymbol,
    );

    final imgProvider = ProductImageHelper.resolveImageProvider(
      imagePath: widget.product.imagePath,
      productName: widget.product.name,
      categoryId: widget.product.categoryId,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(
          children: [
            // Header Bar with Product Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image(
                        image: imgProvider,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.fastfood_rounded,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
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
                          'Base Price: $currency${widget.product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
            ),

            // Options Body (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Variant Groups (Size, Flavor, Milk, Temperature, etc.)
                    for (final grp in _config.customGroups) ...[
                      if (grp.options.isNotEmpty) ...[
                        _buildSectionTitle(
                          icon: Icons.tune_rounded,
                          title: grp.name,
                          subtitle: 'Select ${grp.name.toLowerCase()} option',
                        ),
                        const SizedBox(height: 8),
                        _buildPillSelector(
                          options: grp.options,
                          selected: _selectedCustomOptions[grp.id] ?? grp.options.first,
                          onSelected: (val) => setState(() => _selectedCustomOptions[grp.id] = val),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ],

                    // Sugar Level Section
                    if (_config.hasSugar) ...[
                      _buildSectionTitle(
                        icon: Icons.water_drop_outlined,
                        title: 'Sugar Level',
                        subtitle: 'Select sweetness preference',
                      ),
                      const SizedBox(height: 8),
                      _buildPillSelector(
                        options: _sugarOptions,
                        selected: _sugarLevel,
                        onSelected: (val) => setState(() => _sugarLevel = val),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Ice Level Section
                    if (_config.hasIce) ...[
                      _buildSectionTitle(
                        icon: Icons.ac_unit_rounded,
                        title: 'Ice Level',
                        subtitle: 'Select ice preference',
                      ),
                      const SizedBox(height: 8),
                      _buildPillSelector(
                        options: _iceOptions,
                        selected: _iceLevel,
                        onSelected: (val) => setState(() => _iceLevel = val),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Spiciness Section
                    if (_config.hasSpicy) ...[
                      _buildSectionTitle(
                        icon: Icons.local_fire_department_rounded,
                        title: 'Spiciness Level',
                        subtitle: 'Select spice intensity',
                      ),
                      const SizedBox(height: 8),
                      _buildPillSelector(
                        options: _spicyOptions,
                        selected: _spicyLevel,
                        onSelected: (val) => setState(() => _spicyLevel = val),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Add-on Extras with Extra Charge
                    if (_config.addons.isNotEmpty) ...[
                      _buildSectionTitle(
                        icon: Icons.add_circle_outline_rounded,
                        title: 'Extra Add-ons',
                        subtitle: 'Additional charge applies',
                      ),
                      const SizedBox(height: 8),
                      ..._config.addons.map((addon) {
                        final isSelected = _selectedAddonIds.contains(addon.id);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedAddonIds.remove(addon.id);
                              } else {
                                _selectedAddonIds.add(addon.id);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0D9488).withValues(alpha: 0.08)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF0D9488)
                                    : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  color: isSelected
                                      ? const Color(0xFF0D9488)
                                      : const Color(0xFF94A3B8),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    addon.name,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF0D9488)
                                        : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+$currency${addon.price.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 14),
                    ],

                    // Quantity Stepper
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                onPressed: _quantity > 1
                                    ? () => setState(() => _quantity--)
                                    : null,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: _quantity < widget.product.stockQuantity
                                    ? () => setState(() => _quantity++)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Custom Notes / Remarks
                    TextField(
                      controller: _notesCtrl,
                      decoration: InputDecoration(
                        labelText: 'Special Request / Kitchen Note (Optional)',
                        hintText: 'e.g. Less sweet, extra ice, separate bag...',
                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF0D9488),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer Total & Confirm Action
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      Text(
                        '$currency${_lineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _onConfirm,
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: Text(
                        'Add to Cart • $currency${_lineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
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

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0D9488)),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '• $subtitle',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildPillSelector({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return InkWell(
          onTap: () => onSelected(opt),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFF0D9488) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
