import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../domain/entities/shop_entities.dart';
import '../../../core/widgets/repository_scope.dart';
import '../../scanner/screens/barcode_scanner_screen.dart';
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
              PopupMenuButton<String>(
                tooltip: 'مشاركة الأصناف',
                onSelected: (v) {
                  if (v == 'share') {
                    _shareCatalog(context, state);
                  } else {
                    _importCatalog(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'share', child: Text('مشاركة الأصناف لهاتف آخر')),
                  PopupMenuItem(value: 'import', child: Text('استقبال أصناف')),
                ],
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
                                'الكمية: ${p.quantity}${p.barcode.isNotEmpty ? ' | ${p.barcode}' : ''}${p.purchaseUnit.isNotEmpty ? '\nوحدة الشراء: ${p.purchaseUnit} (${p.unitFactor} ${p.unitName}) | تكلفة القطعة: ${p.unitCost.toStringAsFixed(2)}' : ''}',
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
    final purchaseUnit = TextEditingController(text: product?.purchaseUnit ?? '');
    final unitFactor = TextEditingController(
        text: product == null ? '' : (product.unitFactor == 1 ? '' : product.unitFactor.toString()));
    final unitName = TextEditingController(text: product?.unitName ?? '');
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
                Row(
                  children: [
                    Expanded(child: TextField(controller: barcode, decoration: const InputDecoration(labelText: 'الباركود'))),
                    IconButton(
                      tooltip: 'مسح باركود',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        final code = await Navigator.push<String>(
                          ctx,
                          MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
                        );
                        if (code != null) barcode.text = code;
                      },
                    ),
                  ],
                ),
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
                const Divider(),
                const Text('وحدات متعددة (اختياري)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(controller: purchaseUnit, decoration: const InputDecoration(labelText: 'وحدة الشراء (مثال: كرتون)')),
                TextField(controller: unitFactor, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد القطع داخل الوحدة')),
                TextField(controller: unitName, decoration: const InputDecoration(labelText: 'اسم القطعة (مثال: قطعة)')),
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
                      purchaseUnit: purchaseUnit.text.trim(),
                      unitFactor: double.tryParse(unitFactor.text) ?? 1,
                      unitName: unitName.text.trim(),
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

  /// Share all products (with buy/sell prices) as JSON to another phone.
  Future<void> _shareCatalog(BuildContext context, InventoryState state) async {
    if (state.products.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('لا توجد أصناف للمشاركة')));
      return;
    }
    final json = jsonEncode(state.products.map((p) => p.toMap()).toList());
    await SharePlus.instance.share(ShareParams(text: json, subject: 'أصناف المحل'));
  }

  /// Receive products JSON shared from another phone.
  void _importCatalog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استقبال أصناف'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(hintText: 'الصق نص الأصناف هنا...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              try {
                final list = (jsonDecode(ctrl.text.trim()) as List)
                    .map((e) => Product.fromMap(Map<String, Object?>.from(e as Map)))
                    .toList();
                final repo = RepositoryScope.of(context);
                for (final p in list) {
                  await repo.upsertProduct(p);
                }
                if (!context.mounted) return;
                context.read<InventoryCubit>().load();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم استقبال ${list.length} صنف')));
              } catch (_) {
                ScaffoldMessenger.of(ctx)
                    .showSnackBar(const SnackBar(content: Text('نص غير صالح')));
              }
            },
            child: const Text('استقبال'),
          ),
        ],
      ),
    );
  }

  void _categoriesSheet(BuildContext context, InventoryState state) {    final ctrl = TextEditingController();
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
