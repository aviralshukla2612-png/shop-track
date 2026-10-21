import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/expense.dart';
import '../../providers/app_providers.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  List<Expense> _expenses = [];
  bool _isLoading = false;

  final categories = [
    'Shop Rent',
    'Electricity & Utilities',
    'Staff Wages',
    'Tea & Refreshments',
    'Packaging & Bags',
    'Transport & Freight',
    'Miscellaneous'
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final list = await ref.read(expensesRepoProvider).getExpenses();
    if (mounted) {
      setState(() {
        _expenses = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalExpenses = _expenses.fold(0.0, (acc, e) => acc + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operating Expenses', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Record Expense',
            onPressed: _openAddExpenseDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Card
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Logged Expenses', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            CurrencyFormatter.format(totalExpenses),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Log Expense'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentColor),
                        onPressed: _openAddExpenseDialog,
                      ),
                    ],
                  ),
                ),

                // Expense List
                Expanded(
                  child: _expenses.isEmpty
                      ? const Center(child: Text('No operating expenses logged yet.'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _expenses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, idx) {
                            final exp = _expenses[idx];
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade50,
                                  child: const Icon(Icons.receipt, color: AppTheme.accentColor, size: 20),
                                ),
                                title: Text(exp.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  '${exp.category} • ${exp.paymentMode} • ${CurrencyFormatter.formatDateOnly(DateTime.parse(exp.expenseDate))}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                ),
                                trailing: Text(
                                  CurrencyFormatter.format(exp.amount),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _openAddExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = categories.first;
    String paymentMode = 'Cash';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Record Shop Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 380,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Expense Category*'),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) => setDialogState(() => category = val!),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Expense Title / Description*')),
                      const SizedBox(height: 10),
                      TextField(
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Amount (₹)*'),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: paymentMode,
                        decoration: const InputDecoration(labelText: 'Paid via'),
                        items: ['Cash', 'UPI', 'Bank Transfer'].map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) => setDialogState(() => paymentMode = val!),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (Optional)')),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid title and amount.')));
                      return;
                    }

                    final exp = Expense(
                      id: const Uuid().v4(),
                      category: category,
                      title: title,
                      amount: amount,
                      paymentMode: paymentMode,
                      expenseDate: DateTime.now().toIso8601String(),
                      notes: notesCtrl.text.trim(),
                    );

                    await ref.read(expensesRepoProvider).addExpense(exp);
                    ref.invalidate(dashboardMetricsProvider);
                    if (context.mounted) {
                      Navigator.pop(context);
                      await _loadExpenses();
                    }
                  },
                  child: const Text('Save Expense'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
