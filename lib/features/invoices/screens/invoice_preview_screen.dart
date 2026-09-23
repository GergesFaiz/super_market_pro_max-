import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/data/shop_repository.dart';
import '../../../core/models/shop_models.dart';
import '../../../core/settings/shop_settings.dart';
import '../../../core/widgets/repository_scope.dart';

/// Printable-style invoice preview with shop header/logo + share.
class InvoicePreviewScreen extends StatefulWidget {
  final Invoice invoice;
  const InvoicePreviewScreen({super.key, required this.invoice});

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  List<InvoiceItem> _items = [];
  ShopSettings _shop = const ShopSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final repo = RepositoryScope.of(context);
    final items = await repo.getItems(widget.invoice.id);
    final shop = await ShopSettings.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _shop = shop;
      _loading = false;
    });
  }

  String _text() {
    final inv = widget.invoice;
    final date = DateFormat('dd/MM/yyyy hh:mm a', 'ar')
        .format(DateTime.fromMillisecondsSinceEpoch(inv.date));
    final b = StringBuffer()
      ..writeln(_shop.shopName)
      ..writeln([_shop.phone, _shop.address].where((e) => e.isNotEmpty).join(' - '))
      ..writeln('${inv.kind == 'sale' ? 'فاتورة بيع' : 'فاتورة شراء'} - $date')
      ..writeln('--------------------------');
    for (final it in _items) {
      final price = inv.kind == 'sale' ? it.sellPrice : it.buyPrice;
      b.writeln('${it.productName} × ${it.qty} = ${(price * it.qty).toStringAsFixed(2)}');
    }
    b
      ..writeln('--------------------------')
      ..writeln('الإجمالي: ${_shop.money(inv.total)}')
      ..writeln('المدفوع: ${_shop.money(inv.paid)}')
      ..writeln('المتبقي: ${_shop.money(inv.remaining)}');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    return Scaffold(
      appBar: AppBar(
        title: Text(inv.kind == 'sale' ? 'فاتورة بيع' : 'فاتورة شراء'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة الفاتورة',
            onPressed: _loading ? null : () => Share.share(_text()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      if (_shop.hasLogo)
                        Image.file(File(_shop.logoPath), height: 72),
                      Text(_shop.shopName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 22)),
                      if (_shop.phone.isNotEmpty || _shop.address.isNotEmpty)
                        Text(
                            [_shop.phone, _shop.address]
                                .where((e) => e.isNotEmpty)
                                .join(' - '),
                            style: const TextStyle(color: Colors.grey)),
                      Text(
                        DateFormat('dd/MM/yyyy hh:mm a', 'ar').format(
                            DateTime.fromMillisecondsSinceEpoch(inv.date)),
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const Divider(),
                    ],
                  ),
                ),
                ..._items.map((it) {
                  final price = inv.kind == 'sale' ? it.sellPrice : it.buyPrice;
                  return ListTile(
                    title: Text(it.productName),
                    subtitle: Text('${it.qty} × ${price.toStringAsFixed(2)}'),
                    trailing: Text((price * it.qty).toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }),
                const Divider(),
                _row('الإجمالي', _shop.money(inv.total), bold: true),
                if (inv.discount > 0) _row('خصم', _shop.money(inv.discount)),
                _row('المدفوع', _shop.money(inv.paid)),
                _row('المتبقي', _shop.money(inv.remaining),
                    bold: true,
                    color: inv.remaining > 0 ? Colors.red : Colors.green),
              ],
            ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }
}
