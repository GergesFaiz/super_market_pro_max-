import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../cubit/invoices_cubit.dart';
import 'invoice_preview_screen.dart';
import 'new_invoice_screen.dart';

/// History list for one invoice kind ('sale' | 'purchase').
class InvoiceListScreen extends StatelessWidget {
  final String kind;
  const InvoiceListScreen({super.key, required this.kind});

  bool get isSale => kind == 'sale';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvoicesCubit, InvoicesState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(isSale ? 'فواتير البيع' : 'فواتير الشراء')),
          body: state.loading
              ? const Center(child: CircularProgressIndicator())
              : state.invoices.isEmpty
                  ? const Center(child: Text('لا توجد فواتير بعد'))
                  : ListView.builder(
                      itemCount: state.invoices.length,
                      itemBuilder: (context, i) {
                        final inv = state.invoices[i];
                        final date = DateTime.fromMillisecondsSinceEpoch(inv.date);
                        final fmt = DateFormat('dd/MM/yyyy hh:mm a', 'ar');
                        final unpaid = inv.remaining;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        InvoicePreviewScreen(invoice: inv)),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: isSale ? Colors.green : Colors.orange,
                              child: Icon(isSale ? Icons.point_of_sale : Icons.shopping_bag,
                                  color: Colors.white),
                            ),
                            title: Text('إجمالي: ${inv.total.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${fmt.format(date)}\nمدفوع: ${inv.paid} | متبقي: ${unpaid.toStringAsFixed(2)}${inv.discount > 0 ? ' | خصم: ${inv.discount}' : ''}',
                            ),
                            isThreeLine: true,
                            trailing: unpaid > 0
                                ? const Chip(
                                    label: Text('آجل', style: TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.red)
                                : const Chip(
                                    label: Text('خالص', style: TextStyle(color: Colors.white)),
                                    backgroundColor: Colors.green),
                          ),
                        );
                      },
                    ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              final cubit = context.read<InvoicesCubit>();
              cubit.startNew();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NewInvoiceScreen(kind: kind)),
              ).then((_) => cubit.loadHistory(kind));
            },
            icon: const Icon(Icons.add),
            label: Text(isSale ? 'بيع جديد' : 'شراء جديد'),
          ),
        );
      },
    );
  }
}
