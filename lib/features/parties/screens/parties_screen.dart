import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/shop_entities.dart';
import '../cubit/parties_cubit.dart';

/// Customers or suppliers list with balances (kind: 'customer' | 'supplier').
class PartiesScreen extends StatelessWidget {
  final String kind;
  const PartiesScreen({super.key, required this.kind});

  bool get isCustomer => kind == 'customer';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PartiesCubit, PartiesState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(isCustomer ? 'العملاء' : 'الموردون')),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.parties.isEmpty
                  ? const Center(child: Text('لا توجد أسماء مسجلة بعد'))
                  : ListView.builder(
                      itemCount: state.parties.length,
                      itemBuilder: (context, i) {
                        final p = state.parties[i];
                        final owes = p.balance > 0;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(child: Text(p.name.characters.first)),
                            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${p.phone}\nالرصيد: ${p.balance.toStringAsFixed(2)}${owes ? ' (عليه)' : p.balance < 0 ? ' (له)' : ''}'),
                            isThreeLine: true,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _dialog(context, party: p);
                                } else {
                                  context.read<PartiesCubit>().remove(p.id, kind);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                PopupMenuItem(value: 'del', child: Text('حذف')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _dialog(context),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _dialog(BuildContext context, {Party? party}) {
    final name = TextEditingController(text: party?.name ?? '');
    final phone = TextEditingController(text: party?.phone ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(party == null
            ? (isCustomer ? 'عميل جديد' : 'مورد جديد')
            : 'تعديل البيانات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم *')),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'التليفون')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              context.read<PartiesCubit>().save(
                    id: party?.id,
                    name: name.text.trim(),
                    phone: phone.text.trim(),
                    kind: kind,
                  );
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
