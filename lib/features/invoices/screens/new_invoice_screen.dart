import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/shop_models.dart';
import '../../../core/widgets/repository_scope.dart';
import '../../scanner/screens/barcode_scanner_screen.dart';
import '../cubit/invoices_cubit.dart';

/// New invoice: pick products into a cart, set paid/discount/party, save.
class NewInvoiceScreen extends StatefulWidget {
  final String kind;
  const NewInvoiceScreen({super.key, required this.kind});

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen> {
  final _search = TextEditingController();
  List<Product> _filtered = [];
  List<Party> _parties = [];
  bool get isSale => widget.kind == 'sale';
  double priceFor(Product p) => isSale ? p.sellPrice : p.buyPrice;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<InvoicesCubit>();
    _filtered = List.of(cubit.state.catalog);
    _loadParties();
  }

  Future<void> _loadParties() async {
    final repo = RepositoryScope.of(context);
    final list = await repo.getParties(isSale ? 'customer' : 'supplier');
    if (mounted) setState(() => _parties = list);
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;
    final cubit = context.read<InvoicesCubit>();
    final match = cubit.state.catalog.where((p) => p.barcode == code).toList();
    if (match.length == 1) {
      cubit.addToCart(match.first);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تمت إضافة ${match.first.name}')));
      }
      _search.clear();
      _onSearch('');
    } else {
      _search.text = code;
      _onSearch(code);
    }
  }
  void _onSearch(String q) {
    final catalog = context.read<InvoicesCubit>().state.catalog;
    setState(() {
      _filtered = q.trim().isEmpty
          ? List.of(catalog)
          : catalog
              .where((p) =>
                  p.name.contains(q) ||
                  p.barcode.contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InvoicesCubit, InvoicesState>(
      builder: (context, state) {
        final cubit = context.read<InvoicesCubit>();
        final total = state.totalFor(widget.kind);
        return Scaffold(
          appBar: AppBar(title: Text(isSale ? 'فاتورة بيع جديدة' : 'فاتورة شراء جديدة')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'بحث عن منتج...',
                        ),
                        onChanged: _onSearch,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'مسح باركود',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scan,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) {
                    final p = _filtered[i];
                    final inCart = state.cart.where((l) => l.product.id == p.id);
                    final qty = inCart.isEmpty ? 0 : inCart.first.qty;
                    return ListTile(
                      title: Text(p.name),
                      subtitle: Text('السعر: ${priceFor(p)} | مخزون: ${p.quantity}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (qty > 0)
                            IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => cubit.setQty(p.id, qty - 1),
                            ),
                          if (qty > 0)
                            Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.green),
                            onPressed: () => cubit.addToCart(p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: state.partyId,
                      decoration: InputDecoration(
                          labelText: isSale ? 'العميل (اختياري)' : 'المورد (اختياري)'),
                      items: _parties
                          .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                          .toList(),
                      onChanged: cubit.setParty,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'خصم'),
                            onChanged: (v) => cubit.setDiscount(double.tryParse(v) ?? 0),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'المدفوع'),
                            onChanged: (v) => cubit.setPaid(double.tryParse(v) ?? 0),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الإجمالي: ${(total - state.discount).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ElevatedButton(
                          onPressed: () async {
                            final err = await cubit.save(widget.kind);
                            if (!context.mounted) return;
                            if (err != null) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(err)));
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('حفظ الفاتورة'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
