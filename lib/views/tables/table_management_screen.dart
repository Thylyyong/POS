import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_config.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/pos_controller.dart';
import '../../controllers/table_controller.dart';
import '../../database/order_dao.dart';
import '../../models/dining_table_model.dart';

class TableManagementScreen extends StatefulWidget {
  final VoidCallback? onSwitchToPos;

  const TableManagementScreen({super.key, this.onSwitchToPos});

  @override
  State<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends State<TableManagementScreen> {
  final OrderDao _orderDao = OrderDao();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TableController>().loadTables();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tableCtrl = context.watch<TableController>();
    final cartCtrl = context.read<CartController>();
    final posCtrl = context.read<PosController>();

    final tables = tableCtrl.filteredTables;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Top Summary Header Bar ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                const Row(
                  children: [
                    Icon(Icons.table_restaurant, color: AppConfig.accentGreen, size: 26),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Table & Room Management',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Real-time floor map, occupancy & orders',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),

                // Metric Badges
                _buildMetricBadge('Available', '${tableCtrl.availableCount}', AppConfig.accentGreen),
                const SizedBox(width: 10),
                _buildMetricBadge('Occupied', '${tableCtrl.occupiedCount}', AppConfig.accentAmber),
                const SizedBox(width: 10),
                _buildMetricBadge('VIP Rooms', '${tableCtrl.vipCount}', AppConfig.accentPurple),
                const SizedBox(width: 16),

                // "+ Add Table / VIP Room" Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConfig.accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showAddTableDialog(context),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Table / Room', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // ── Filter Chips Bar ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            color: const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Text(
                  'Filters: ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569)),
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(tableCtrl, 'All Status', null),
                const SizedBox(width: 6),
                _buildStatusFilterChip(tableCtrl, 'Available Only', TableStatus.available),
                const SizedBox(width: 6),
                _buildStatusFilterChip(tableCtrl, 'Occupied Only', TableStatus.occupied),
                const SizedBox(width: 16),
                Container(height: 20, width: 1, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 16),
                _buildTypeFilterChip(tableCtrl, 'All Types', null),
                const SizedBox(width: 6),
                _buildTypeFilterChip(tableCtrl, 'Standard', TableType.standard),
                const SizedBox(width: 6),
                _buildTypeFilterChip(tableCtrl, 'VIP Suites', TableType.vipRoom),
                const SizedBox(width: 6),
                _buildTypeFilterChip(tableCtrl, 'Patio / Outdoor', TableType.outdoor),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppConfig.accentGreen),
                  tooltip: 'Refresh Floor',
                  onPressed: () => tableCtrl.loadTables(),
                ),
              ],
            ),
          ),

          // ── Tables Grid ─────────────────────────────────────────────────────
          Expanded(
            child: tableCtrl.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppConfig.accentGreen))
                : tables.isEmpty
                    ? const Center(
                        child: Text(
                          'No tables found matching filter',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 1.25,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: tables.length,
                        itemBuilder: (context, index) {
                          final table = tables[index];
                          return _buildTableCard(context, table, cartCtrl, posCtrl, tableCtrl);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBadge(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(TableController ctrl, String label, TableStatus? status) {
    final isSelected = ctrl.filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ctrl.setFilterStatus(status),
      selectedColor: AppConfig.accentGreen.withValues(alpha: 0.18),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppConfig.accentGreenDark : const Color(0xFF475569),
      ),
      side: BorderSide(color: isSelected ? AppConfig.accentGreen : const Color(0xFFCBD5E1)),
    );
  }

  Widget _buildTypeFilterChip(TableController ctrl, String label, TableType? type) {
    final isSelected = ctrl.filterType == type;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => ctrl.setFilterType(type),
      selectedColor: AppConfig.accentPurple.withValues(alpha: 0.18),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppConfig.accentPurple : const Color(0xFF475569),
      ),
      side: BorderSide(color: isSelected ? AppConfig.accentPurple : const BorderSide().color),
    );
  }

  Widget _buildTableCard(
    BuildContext context,
    DiningTableModel table,
    CartController cartCtrl,
    PosController posCtrl,
    TableController tableCtrl,
  ) {
    final isOccupied = table.isOccupied;
    final isVip = table.isVip;

    Color statusColor = isOccupied ? AppConfig.accentAmber : AppConfig.accentGreen;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOccupied ? AppConfig.accentAmber.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          width: isOccupied ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOccupied
                ? AppConfig.accentAmber.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Row 1: Table # + Status Badge + Menu popup
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isVip ? AppConfig.accentPurple.withValues(alpha: 0.15) : const Color(0xFF0F172A).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          if (isVip) ...[
                            const Icon(Icons.star, size: 14, color: AppConfig.accentPurple),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            table.tableNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isVip ? AppConfig.accentPurple : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    table.status.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val == 'free') {
                      tableCtrl.freeTable(table.id);
                    } else if (val == 'delete') {
                      _confirmDeleteTable(context, table, tableCtrl);
                    }
                  },
                  itemBuilder: (_) => [
                    if (isOccupied)
                      const PopupMenuItem(
                        value: 'free',
                        child: Row(
                          children: [
                            Icon(Icons.check, size: 16, color: AppConfig.accentGreen),
                            SizedBox(width: 8),
                            Text('Mark Available'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: AppConfig.accentRose),
                          SizedBox(width: 8),
                          Text('Delete Table'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Row 2: Table Name & Capacity
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  table.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.people_outline, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      '${table.capacity} Seats • ${table.type.displayName}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ],
            ),

            // Row 3: Occupied Info or Available Status
            if (isOccupied)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        table.customerName ?? 'Guest Order',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (table.orderTotal != null)
                      Text(
                        '\$${table.orderTotal!.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                        ),
                      ),
                  ],
                ),
              ),

            // Row 4: Action Button
            SizedBox(
              width: double.infinity,
              height: 36,
              child: isOccupied
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.accentAmber,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _handleOpenOccupiedOrder(table, cartCtrl, posCtrl),
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Open / Pay Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.accentGreen,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        cartCtrl.setTableInfo(
                          tableId: table.id,
                          tableNumber: table.tableNumber,
                          customerName: null,
                          orderType: 'DINE_IN',
                        );
                        widget.onSwitchToPos?.call();
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('Start Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleOpenOccupiedOrder(
    DiningTableModel table,
    CartController cartCtrl,
    PosController posCtrl,
  ) async {
    if (table.currentOrderId == null) {
      cartCtrl.setTableInfo(
        tableId: table.id,
        tableNumber: table.tableNumber,
        customerName: table.customerName,
        orderType: 'DINE_IN',
      );
      widget.onSwitchToPos?.call();
      return;
    }

    final order = await _orderDao.getOrderById(table.currentOrderId!);
    if (order != null) {
      posCtrl.loadPendingOrderIntoCart(order, cartCtrl);
    } else {
      cartCtrl.setTableInfo(
        tableId: table.id,
        tableNumber: table.tableNumber,
        customerName: table.customerName,
        orderType: 'DINE_IN',
      );
    }
    widget.onSwitchToPos?.call();
  }

  void _showAddTableDialog(BuildContext context) {
    final tableCtrl = context.read<TableController>();
    final numCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    int capacity = 4;
    TableType selectedType = TableType.standard;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add New Table / Room',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: numCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Table Number (e.g. T09, VIP-3, Patio-3)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description / Room Name',
                    hintText: 'e.g. Window Booth, Grand Dining Room',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Capacity (Seats): ', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: capacity > 1 ? () => setDialogState(() => capacity--) : null,
                    ),
                    Text('$capacity Seats', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setDialogState(() => capacity++),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TableType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Table Type', border: OutlineInputBorder()),
                  items: TableType.values.map((t) {
                    return DropdownMenuItem(value: t, child: Text(t.displayName));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accentGreen, foregroundColor: Colors.white),
                        onPressed: () async {
                          if (numCtrl.text.trim().isEmpty) return;
                          await tableCtrl.addTable(
                            tableNumber: numCtrl.text.trim(),
                            name: nameCtrl.text.trim().isEmpty ? 'Table ${numCtrl.text.trim()}' : nameCtrl.text.trim(),
                            capacity: capacity,
                            type: selectedType,
                          );
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        },
                        child: const Text('Create Table'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteTable(BuildContext context, DiningTableModel table, TableController tableCtrl) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${table.tableNumber}?'),
        content: Text('Are you sure you want to remove ${table.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.accentRose, foregroundColor: Colors.white),
            onPressed: () async {
              await tableCtrl.deleteTable(table.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
