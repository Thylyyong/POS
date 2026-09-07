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
  String _selectedCategory = 'OPERATING';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final accounting = context.read<AccountingController>();

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

            // Category Dropdown
            const Text(
              'Category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
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
              items: const [
                DropdownMenuItem(
                  value: 'OPERATING',
                  child: Text('General Operating'),
                ),
                DropdownMenuItem(
                  value: 'SALARIES',
                  child: Text('Staff Wages / Payroll'),
                ),
                DropdownMenuItem(
                  value: 'UTILITIES',
                  child: Text('Electricity & Water'),
                ),
                DropdownMenuItem(
                  value: 'SUPPLIES',
                  child: Text('Store Supplies & Paper'),
                ),
                DropdownMenuItem(value: 'RENT', child: Text('Facility Rent')),
              ],
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
                      category: _selectedCategory,
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
