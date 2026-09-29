
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../controllers/accounting_controller.dart';
import '../../../controllers/auth_controller.dart';

class LogExpenseDialog extends StatefulWidget {
  const LogExpenseDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const LogExpenseDialog(),
    );
  }

  @override
  State<LogExpenseDialog> createState() => _LogExpenseDialogState();
}

class _LogExpenseDialogState extends State<LogExpenseDialog> {
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountingController>().loadExpenseCategories();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _showManageCategoriesDialog(
    BuildContext context,
    AccountingController accounting,
  ) {
    final newCatCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final categories = accounting.expenseCategories;

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.category_outlined, color: Color(0xFF0F766E), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Manage Expense Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 380,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create new categories or delete categories you do not need:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newCatCtrl,
                            decoration: InputDecoration(
                              hintText: 'e.g. Marketing, Delivery...',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onSubmitted: (val) async {
                              if (val.trim().isNotEmpty) {
                                await accounting.addExpenseCategory(val.trim());
                                newCatCtrl.clear();
                                setModalState(() {});
                                setState(() {
                                  _selectedCategory = val.trim();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () async {
                            final val = newCatCtrl.text.trim();
                            if (val.isNotEmpty) {
                              await accounting.addExpenseCategory(val);
                              newCatCtrl.clear();
                              setModalState(() {});
                              setState(() {
                                _selectedCategory = val;
                              });
                            }
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Current Categories:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, idx) {
                          final cat = categories[idx];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 0,
                            ),
                            title: Text(
                              cat,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                              tooltip: 'Delete Category',
                              onPressed: () async {
                                await accounting.deleteExpenseCategory(cat);
                                setModalState(() {});
                                setState(() {
                                  if (_selectedCategory == cat) {
                                    _selectedCategory =
                                        accounting.expenseCategories.isNotEmpty
                                            ? accounting.expenseCategories.first
                                            : null;
                                  }
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final accounting = context.watch<AccountingController>();
    final categories = accounting.expenseCategories;

    if (_selectedCategory == null || !categories.contains(_selectedCategory)) {
      _selectedCategory = categories.isNotEmpty ? categories.first : 'General Operating';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Log Operating Expense',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),

            // Category Dropdown with Create & Delete button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Category',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF475569),
                  ),
                ),
                InkWell(
                  onTap: () => _showManageCategoriesDialog(context, accounting),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      children: [
                        Icon(Icons.tune_outlined, size: 14, color: Color(0xFF0F766E)),
                        SizedBox(width: 4),
                        Text(
                          '+ Add / Delete Category',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat,
                  child: Text(cat),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 12),

            // Title
            const Text(
              'Expense Title',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Air conditioning maintenance',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Amount
            const Text(
              'Amount (\$)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                prefixText: '\$ ',
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Notes
            const Text(
              'Notes (Optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add invoice reference or details...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF714B67),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final amount =
                        double.tryParse(
                          _amountCtrl.text.replaceAll('\$', '').trim(),
                        ) ??
                        0.0;
                    if (_titleCtrl.text.trim().isEmpty || amount <= 0) return;

                    await accounting.addExpense(
                      branchId: auth.currentBranchId,
                      category: _selectedCategory ?? 'General Operating',
                      title: _titleCtrl.text.trim(),
                      amount: amount,
                      notes: _notesCtrl.text.trim(),
                      loggedByUserId: auth.currentUser.id,
                      loggedByUserName: auth.currentUser.displayName,
                    );

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Save Expense'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
