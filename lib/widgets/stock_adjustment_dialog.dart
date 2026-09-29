import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/pos_controller.dart';
import '../core/product_image_helper.dart';
import '../database/product_dao.dart';
import '../models/product_model.dart';
import 'admin_pin_dialog.dart';

/// Modal dialog for Managers/Store Owners to adjust stock and log waste
/// with mandatory reason codes, live resulting count calculation, and audit logging.
class StockAdjustmentDialog extends StatefulWidget {
  final Product product;
  final VoidCallback onSaved;

  const StockAdjustmentDialog({
    super.key,
    required this.product,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required Product product,
    required VoidCallback onSaved,
  }) async {
    final auth = context.read<AuthController>();
    if (!auth.isOwner && !auth.isAdminAuthenticated) {
      final verified = await AdminPinDialog.show(
        context,
        title: 'Manager Authorization',
        subtitle: 'Stock adjustments & waste logging require manager authorization.',
      );
      if (!verified || !context.mounted) return;
    }

    if (!context.mounted) return;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => StockAdjustmentDialog(
        product: product,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  final ProductDao _productDao = ProductDao();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');
  final TextEditingController _notesCtrl = TextEditingController();

  // Reason code selection:
  // vendor_delivery, recount, damaged, expired, waste, other
  String _selectedReason = 'vendor_delivery';
  bool _isSaving = false;

  final Map<String, _ReasonMeta> _reasonMap = {
    'vendor_delivery': _ReasonMeta(
      label: 'Vendor Delivery / Restock',
      icon: Icons.local_shipping_outlined,
      color: Color(0xFF0D9488),
      isAddition: true,
      helper: 'New stock delivered from supplier (+)',
    ),
    'recount': _ReasonMeta(
      label: 'Physical Recount',
      icon: Icons.inventory_2_outlined,
      color: Color(0xFF3B82F6),
      isAddition: null, // Sets absolute count
      helper: 'Audit recount: sets exact physical on-hand quantity',
    ),
    'damaged': _ReasonMeta(
      label: 'Damaged Goods (Waste)',
      icon: Icons.broken_image_outlined,
      color: Color(0xFFEF4444),
      isAddition: false,
      helper: 'Drop, broken packaging, or transit damage (-)',
    ),
    'expired': _ReasonMeta(
      label: 'Expired Item (Waste)',
      icon: Icons.event_busy_outlined,
      color: Color(0xFFF97316),
      isAddition: false,
      helper: 'Past expiration date / spoilage write-off (-)',
    ),
    'waste': _ReasonMeta(
      label: 'Kitchen / Prep Waste',
      icon: Icons.delete_sweep_outlined,
      color: Color(0xFFE11D48),
      isAddition: false,
      helper: 'Kitchen burned/spilled or prep scrap write-off (-)',
    ),
    'other': _ReasonMeta(
      label: 'Other Manual Adjustment',
      icon: Icons.tune_rounded,
      color: Color(0xFF64748B),
      isAddition: true,
      helper: 'Correction or miscellaneous adjustment (+ or -)',
    ),
  };

  int get _parsedQty => int.tryParse(_qtyCtrl.text.trim()) ?? 0;

  int get _calculatedNewStock {
    final meta = _reasonMap[_selectedReason]!;
    final current = widget.product.stockQuantity;
    final qty = _parsedQty;

    if (meta.isAddition == true) {
      return (current + qty).clamp(0, 999999);
    } else if (meta.isAddition == false) {
      return (current - qty).clamp(0, 999999);
    } else {
      // Recount: qty is the new absolute stock
      return qty.clamp(0, 999999);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAdjustment() async {
    final qty = _parsedQty;
    if (qty <= 0 && _selectedReason != 'recount') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity greater than 0')),
      );
      return;
    }

    final notes = _notesCtrl.text.trim();
    final meta = _reasonMap[_selectedReason]!;
    final isWaste = _selectedReason == 'damaged' ||
        _selectedReason == 'expired' ||
        _selectedReason == 'waste';

    if (isWaste && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a note explaining the reason for waste/loss'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final auth = context.read<AuthController>();
      final isRecount = _selectedReason == 'recount';
      final changeAmount = isRecount ? qty : (meta.isAddition == true ? qty : -qty);

      await _productDao.adjustProductStock(
        productId: widget.product.id,
        quantityChange: changeAmount,
        reasonCode: _selectedReason,
        notes: notes.isNotEmpty ? notes : meta.label,
        userId: auth.currentUser.id,
        userName: auth.currentUser.displayName,
        userRole: auth.currentUser.role.name,
        absoluteCount: isRecount,
      );

      // Refresh PosController
      if (mounted) {
        await context.read<PosController>().loadProducts();
      }

      widget.onSaved();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stock adjusted for "${widget.product.name}": $_calculatedNewStock on hand',
            ),
            backgroundColor: const Color(0xFF0D9488),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to adjust stock: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _reasonMap[_selectedReason]!;
    final imgProvider = ProductImageHelper.resolveImageProvider(
      imagePath: widget.product.imagePath,
      productName: widget.product.name,
      categoryId: widget.product.categoryId,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image(
                      image: imgProvider,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF64748B),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        Text(
                          'SKU: ${widget.product.barcode ?? "N/A"} • On Hand: ${widget.product.stockQuantity}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // ── Reason Code Selector ─────────────────────────────────
              const Text(
                'Reason for Adjustment / Waste *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedReason,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                    items: _reasonMap.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Row(
                          children: [
                            Icon(e.value.icon, size: 18, color: e.value.color),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.value.label,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedReason = val;
                          if (val == 'recount') {
                            _qtyCtrl.text = '${widget.product.stockQuantity}';
                          } else if (_qtyCtrl.text == '${widget.product.stockQuantity}') {
                            _qtyCtrl.text = '1';
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                meta.helper,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // ── Quantity & Live Result Preview ───────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity Input
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedReason == 'recount'
                              ? 'New Physical Count *'
                              : 'Units Count *',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: '1',
                            prefixIcon: Icon(
                              meta.isAddition == true
                                  ? Icons.add_circle_outline_rounded
                                  : (meta.isAddition == false
                                      ? Icons.remove_circle_outline_rounded
                                      : Icons.edit_note_rounded),
                              size: 18,
                              color: meta.color,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            fillColor: const Color(0xFFF8FAFC),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Resulting Stock Calculation Box
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Stock Impact',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Current', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  Text(
                                    '${widget.product.stockQuantity}',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                              Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey.shade500),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('New Stock', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                  Text(
                                    '$_calculatedNewStock',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: _calculatedNewStock > 0 ? const Color(0xFF0D9488) : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Notes / Reason Details ──────────────────────────────
              const Text(
                'Notes & Reference (Audit Log Details)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g., Supplier Invoice #INV-1092, or Dropped in kitchen...',
                  hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                  contentPadding: const EdgeInsets.all(12),
                  fillColor: const Color(0xFFF8FAFC),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // ── Actions ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submitAdjustment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: meta.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Record Adjustment',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
}

class _ReasonMeta {
  final String label;
  final IconData icon;
  final Color color;
  final bool? isAddition; // true: add, false: deduct, null: absolute
  final String helper;

  const _ReasonMeta({
    required this.label,
    required this.icon,
    required this.color,
    required this.isAddition,
    required this.helper,
  });
}
