import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/models/shop_models.dart';
import '../cubit/inventory_cubit.dart';

/// Inventory: product list + search + add/edit + stock +/- + categories.
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('المخزن والمنتجات'),
            actions: [
              IconButton(
                icon: const Icon(Icons.category),
                tooltip: 'التصنيفات',
                onPressed: () => _categoriesSheet(context, state),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'بحث بالاسم أو الباركود...',
                  ),
                  onChanged: (v) => context.read<InventoryCubit>().setQuery(v),
                ),
              ),
              if (state.loading) const LinearProgressIndicator(),
              Expanded(
                child: state.products.isEmpty
                    ? const Center(child: Text('لا توجد منتجات. أضف أول منتج بالزر +'))
                    : ListView.builder(
                        itemCount: state.products.length,
                        itemBuilder: (context, i) {
                          final p = state.products[i];
                          final low = p.quantity <= 5;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(p.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'شراء: ${p.buyPrice} | بيع: ${p.sellPrice} | ربح: ${(p.sellPrice - p.buyPrice).toStringAsFixed(2)}\n'
                                'الكمية: ${p.quantity}${p.barcode.isNotEmpty ? ' | ${p.barcode}' : ''}',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, color: Colors.red),
                                    onPressed: () => context
                                        .read<InventoryCubit>()
                                        .adjustStock(p.id, -1),
                                  ),
                                  Text('${p.quantity}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: low ? Colors.red : Colors.green)),
                                  IconButton(
                                    icon: const Icon(Icons.add, color: Colors.green),
                                    onPressed: () => context
                                        .read<InventoryCubit>()
                                        .adjustStock(p.id, 1),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') {
                                        _productDialog(context, state, product: p);
                                      } else {
                                        context.read<InventoryCubit>().deleteProduct(p.id);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'edit', child: Text('تعديل')),
                                      PopupMenuItem(value: 'del', child: Text('حذف')),
                                    ],
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
            onPressed: () => _productDialog(context, state),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  void _productDialog(BuildContext context, InventoryState state, {Product? product}) {
    final name = TextEditingController(text: product?.name ?? '');
    final barcode = TextEditingController(text: product?.barcode ?? '');
    final buy = TextEditingController(text: product?.buyPrice.toString() ?? '');
    final sell = TextEditingController(text: product?.sellPrice.toString() ?? '');
    final qty = TextEditingController(text: product == null ? '0' : product.quantity.toString());
    String? catId = product?.categoryId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(product == null ? 'منتج جديد' : 'تعديل منتج'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المنتج *')),
                TextField(controller: barcode, decoration: const InputDecoration(labelText: 'الباركود')),
                DropdownButtonFormField<String>(
                  initialValue: catId,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: state.categories
                      .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => catId = v),
                ),
                TextField(controller: buy, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الشراء *')),
                TextField(controller: sell, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع *')),
                if (product == null)
                  TextField(controller: qty, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية الافتتاحية')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () {
                final b = double.tryParse(buy.text) ?? -1;
                final s = double.tryParse(sell.text) ?? -1;
                if (name.text.trim().isEmpty || b < 0 || s < 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('أكمل الاسم والأسعار بشكل صحيح')));
                  return;
                }
                context.read<InventoryCubit>().saveProduct(
                      id: product?.id,
                      name: name.text.trim(),
                      barcode: barcode.text.trim(),
                      categoryId: catId,
                      buyPrice: b,
                      sellPrice: s,
                      quantity: double.tryParse(qty.text) ?? 0,
                    );
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _categoriesSheet(BuildContext context, InventoryState state) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('التصنيفات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Row(
              children: [
                Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'تصنيف جديد...'))),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                  onPressed: () {
                    if (ctrl.text.trim().isNotEmpty) {
                      context.read<InventoryCubit>().addCategory(ctrl.text.trim());
                      ctrl.clear();
                    }
                  },
                ),
              ],
            ),
            ...state.categories.map((c) => ListTile(
                  title: Text(c.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => context.read<InventoryCubit>().deleteCategory(c.id),
                  ),
                )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
