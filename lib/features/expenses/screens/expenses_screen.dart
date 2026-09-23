import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/shop_models.dart';
import '../../../core/widgets/repository_scope.dart';

/// Daily shop expenses (rent, salaries, utilities...).
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Expense> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = RepositoryScope.of(context);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final list = await repo.getExpensesInRange(from, now.millisecondsSinceEpoch + 1);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _remove(String id) async {
    await RepositoryScope.of(context).deleteExpense(id);
    _load();
  }

  void _dialog() {
    final title = TextEditingController();
    final amount = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مصروف جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'البيان (إيجار، كهرباء...) *')),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ *')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final v = double.tryParse(amount.text) ?? -1;
              if (title.text.trim().isEmpty || v < 0) return;
              await RepositoryScope.of(context).addExpense(Expense(
                id: const Uuid().v4(),
                title: title.text.trim(),
                amount: v,
                date: DateTime.now().millisecondsSinceEpoch,
              ));
              if (!context.mounted) return;
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold(0.0, (s, e) => s + e.amount);
    final fmt = DateFormat('dd/MM/yyyy', 'ar');
    return Scaffold(
      appBar: AppBar(title: const Text('المصاريف')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('إجمالي مصاريف الشهر: ${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('لا توجد مصاريف مسجلة'))
                      : ListView.builder(
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final e = _items[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: const Icon(Icons.money_off, color: Colors.red),
                                title: Text(e.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(fmt.format(
                                    DateTime.fromMillisecondsSinceEpoch(e.date))),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(e.amount.toStringAsFixed(2),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, color: Colors.red)),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.grey),
                                      onPressed: () => _remove(e.id),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _dialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
