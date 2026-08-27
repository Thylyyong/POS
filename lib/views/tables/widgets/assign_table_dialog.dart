import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../app_config.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/pos_controller.dart';
import '../../../controllers/table_controller.dart';
import '../../../database/order_dao.dart';
import '../../../models/dining_table_model.dart';

class AssignTableDialog extends StatefulWidget {
  const AssignTableDialog({super.key});

  @override
  State<AssignTableDialog> createState() => _AssignTableDialogState();
}

class _AssignTableDialogState extends State<AssignTableDialog> {
  final _customerNameCtrl = TextEditingController();
  final OrderDao _orderDao = OrderDao();
  String _selectedOrderType = 'DINE_IN';
  DiningTableModel? _selectedTable;
  TableType? _typeFilter;
  bool _isLoadingOrder = false;

  @override
  void initState() {
    super.initState();
    final cart = context.read<CartController>();
    if (cart.customerName != null) {
      _customerNameCtrl.text = cart.customerName!;
    }
    _selectedOrderType = cart.orderType;
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm(
    CartController cartCtrl,
    PosController posCtrl,
  ) async {
    if (_selectedOrderType == 'TAKEAWAY') {
      cartCtrl.setTableInfo(
        tableId: null,
        tableNumber: 'Takeaway',
        customerName: _customerNameCtrl.text,
        orderType: 'TAKEAWAY',
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (_selectedTable == null) {
      cartCtrl.setTableInfo(
        customerName: _customerNameCtrl.text,
        orderType: _selectedOrderType,
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // ── If table is Occupied (Active Dining / Pending Order) ───────────────
    if (_selectedTable!.isOccupied) {
      if (_selectedTable!.currentOrderId != null) {
        setState(() => _isLoadingOrder = true);
        try {
          final existingOrder = await _orderDao.getOrderById(_selectedTable!.currentOrderId!);
          if (existingOrder != null && mounted) {
            if (cartCtrl.isEmpty) {
              // Load table order into cart for adding more items / checkout
              posCtrl.loadPendingOrderIntoCart(existingOrder, cartCtrl);
            } else {
              // Merge current cart items into existing table order
              posCtrl.mergePendingOrderWithCart(existingOrder, cartCtrl);
            }
          } else {
            cartCtrl.setTableInfo(
              tableId: _selectedTable!.id,
              tableNumber: _selectedTable!.tableNumber,
              customerName: _selectedTable!.customerName ?? _customerNameCtrl.text,
              orderType: 'DINE_IN',
            );
          }
        } finally {
          if (mounted) setState(() => _isLoadingOrder = false);
        }
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // ── Table is Available ────────────────────────────────────────────────
    cartCtrl.setTableInfo(
      tableId: _selectedTable?.id,
      tableNumber: _selectedTable?.tableNumber,
      customerName: _customerNameCtrl.text,
      orderType: 'DINE_IN',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tableCtrl = context.watch<TableController>();
    final cartCtrl = context.watch<CartController>();
    final posCtrl = context.read<PosController>();

    final tables = tableCtrl.tables.where((t) {
      if (_typeFilter != null && t.type != _typeFilter) return false;
      return true;
    }).toList();

    final isSelectedOccupied = _selectedTable?.isOccupied == true;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.table_restaurant, color: AppConfig.accentGreen, size: 26),
                      SizedBox(width: 10),
                      Text(
                        'Select Table & Customer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Order Type Toggle (Dine-in vs Takeaway)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedOrderType = 'DINE_IN';
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedOrderType == 'DINE_IN' ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedOrderType == 'DINE_IN'
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant,
                                size: 18,
                                color: _selectedOrderType == 'DINE_IN' ? AppConfig.accentGreen : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Dine-In (Table)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedOrderType == 'DINE_IN' ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedOrderType = 'TAKEAWAY';
                          _selectedTable = null;
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedOrderType == 'TAKEAWAY' ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _selectedOrderType == 'TAKEAWAY'
                                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.takeout_dining,
                                size: 18,
                                color: _selectedOrderType == 'TAKEAWAY' ? AppConfig.accentCyan : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Takeaway / To-Go',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedOrderType == 'TAKEAWAY' ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Customer Name input
              TextField(
                controller: _customerNameCtrl,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Customer Name / Phone (Optional)',
                  hintText: 'e.g. John Doe, Table 4 Guest',
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                ),
              ),
              const SizedBox(height: 14),

              // Tables section (only for Dine-in)
              if (_selectedOrderType == 'DINE_IN') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Dining Table / VIP Room:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    // Quick filters
                    Row(
                      children: [
                        _buildFilterChip('All', null),
                        const SizedBox(width: 6),
                        _buildFilterChip('VIP', TableType.vipRoom),
                        const SizedBox(width: 6),
                        _buildFilterChip('Patio', TableType.outdoor),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: tables.isEmpty
                      ? const Center(child: Text('No tables configured', style: TextStyle(color: Color(0xFF94A3B8))))
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.35,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: tables.length,
                          itemBuilder: (context, index) {
                            final table = tables[index];
                            final isSelected = _selectedTable?.id == table.id;
                            final isAvailable = table.isAvailable;

                            Color badgeColor = isAvailable ? AppConfig.accentGreen : AppConfig.accentAmber;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedTable = table;
                                  if (table.customerName != null && table.customerName!.isNotEmpty) {
                                    _customerNameCtrl.text = table.customerName!;
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (table.isOccupied
                                          ? AppConfig.accentAmber.withValues(alpha: 0.15)
                                          : AppConfig.accentGreen.withValues(alpha: 0.1))
                                      : isAvailable
                                          ? const Color(0xFFF8FAFC)
                                          : const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? (table.isOccupied ? AppConfig.accentAmber : AppConfig.accentGreen)
                                        : isAvailable
                                            ? const Color(0xFFE2E8F0)
                                            : AppConfig.accentAmber.withValues(alpha: 0.6),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          table.tableNumber,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: isSelected
                                                ? (table.isOccupied ? const Color(0xFF92400E) : AppConfig.accentGreenDark)
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            table.status.displayName,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      table.isOccupied && table.customerName != null
                                          ? 'Guest: ${table.customerName}'
                                          : table.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: table.isOccupied ? FontWeight.w600 : FontWeight.normal,
                                        color: table.isOccupied ? const Color(0xFF92400E) : const Color(0xFF64748B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.people_outline, size: 13, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${table.capacity} Seats',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                        ),
                                        if (table.isOccupied && table.orderTotal != null) ...[
                                          const Spacer(),
                                          Text(
                                            '\$${table.orderTotal!.toStringAsFixed(2)}',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                          ),
                                        ] else if (table.isVip) ...[
                                          const Spacer(),
                                          const Icon(Icons.star, size: 14, color: AppConfig.accentPurple),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Occupied Notice Banner
                if (isSelectedOccupied)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppConfig.accentAmber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF92400E), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            cartCtrl.isEmpty
                                ? 'Table ${_selectedTable!.tableNumber} is eating/pending. Confirming will load existing order to add more items.'
                                : 'Table ${_selectedTable!.tableNumber} is active. Confirming will merge current cart items into this table order.',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else
                const Spacer(),

              const SizedBox(height: 16),

              // Confirm / Action Button
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelectedOccupied
                            ? (cartCtrl.isEmpty ? AppConfig.accentAmber : AppConfig.accentPurple)
                            : AppConfig.accentGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isLoadingOrder ? null : () => _handleConfirm(cartCtrl, posCtrl),
                      icon: _isLoadingOrder
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              isSelectedOccupied
                                  ? (cartCtrl.isEmpty ? Icons.edit_note : Icons.call_merge)
                                  : Icons.check_circle,
                              size: 18,
                            ),
                      label: Text(
                        _selectedOrderType == 'TAKEAWAY'
                            ? 'Set as Takeaway'
                            : isSelectedOccupied
                                ? (cartCtrl.isEmpty
                                    ? 'Load Table ${_selectedTable!.tableNumber} Order'
                                    : 'Merge Items with Table ${_selectedTable!.tableNumber}')
                                : _selectedTable != null
                                    ? 'Assign Table ${_selectedTable!.tableNumber}'
                                    : 'Confirm',
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

  Widget _buildFilterChip(String label, TableType? type) {
    final isSelected = _typeFilter == type;
    return InkWell(
      onTap: () => setState(() => _typeFilter = type),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppConfig.accentGreen.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppConfig.accentGreen : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppConfig.accentGreenDark : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
