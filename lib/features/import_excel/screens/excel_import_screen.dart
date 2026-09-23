import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/shop_repository.dart';
import '../../../core/models/shop_models.dart';
import '../../../core/widgets/repository_scope.dart';

class _ExcelRow {
  final String name;
  final String barcode;
  final double qty;
  final double buy;
  final double sell;
  const _ExcelRow(this.name, this.barcode, this.qty, this.buy, this.sell);
}

/// Import a purchase invoice from an .xlsx file.
///
/// Expected columns (first row may be a header):
/// name | barcode | qty | buy_price | sell_price
class ExcelImportScreen extends StatefulWidget {
  const ExcelImportScreen({super.key});

  @override
  State<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends State<ExcelImportScreen> {
  List<_ExcelRow> _rows = [];
  String _fileName = '';
  bool _busy = false;
  final _paid = TextEditingController();

  double get _total => _rows.fold(0, (s, r) => s + r.qty * r.buy);

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    final bytes = res?.files.single.bytes;
    if (bytes == null) return;
    setState(() {
      _busy = true;
      _fileName = res!.files.single.name;
    });
    try {
      final excel = Excel.decodeBytes(bytes);
      final table = excel.tables.values.first;
      final parsed = <_ExcelRow>[];
      for (final row in table.rows) {
        final cells = row.map((c) => c?.value?.toString().trim() ?? '').toList();
        while (cells.length < 5) {
          cells.add('');
        }
        final qty = double.tryParse(cells[2]);
        final buy = double.tryParse(cells[3]);
        if (cells[0].isEmpty || qty == null || buy == null) continue; // header/empty
        parsed.add(_ExcelRow(
          cells[0],
          cells[1],
          qty,
          buy,
          double.tryParse(cells[4]) ?? buy,
        ));
      }
      if (!mounted) return;
      setState(() => _rows = parsed);
      if (parsed.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('لم يتم العثور على أصناف. تأكد من الأعمدة: الاسم، الباركود، الكمية، سعر الشراء، سعر البيع')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر قراءة الملف')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_rows.isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = RepositoryScope.of(context);
      final uuid = const Uuid();
      final now = DateTime.now().millisecondsSinceEpoch;
      final existing = await repo.getProducts();
      final byBarcode = {for (final p in existing) p.barcode: p};
      final byName = {for (final p in existing) p.name: p};

      final items = <InvoiceItem>[];
      final invoiceId = uuid.v4();
      for (final r in _rows) {
        var product = (r.barcode.isNotEmpty ? byBarcode[r.barcode] : null) ?? byName[r.name];
        product ??= Product(
          id: uuid.v4(),
          name: r.name,
          barcode: r.barcode,
          buyPrice: r.buy,
          sellPrice: r.sell,
          quantity: 0,
          createdAt: now,
        );
        await repo.upsertProduct(product.copyWith(
          buyPrice: r.buy,
          sellPrice: r.sell,
        ));
        items.add(InvoiceItem(
          id: uuid.v4(),
          invoiceId: invoiceId,
          productId: product.id,
          productName: product.name,
          qty: r.qty,
          buyPrice: r.buy,
          sellPrice: r.buy,
        ));
      }
      final paid = double.tryParse(_paid.text) ?? 0;
      await repo.saveInvoice(
        Invoice(
          id: invoiceId,
          kind: 'purchase',
          total: _total,
          paid: paid.clamp(0, _total).toDouble(),
          date: now,
          notes: 'استيراد Excel: $_fileName',
        ),
        items,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حفظ فاتورة شراء بـ ${_rows.length} صنف')));
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد مشتريات من Excel')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text('الأعمدة: الاسم | الباركود | الكمية | سعر الشراء | سعر البيع'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_fileName.isEmpty ? 'اختر ملف xlsx' : _fileName),
                ),
              ],
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final r = _rows[i];
                return ListTile(
                  title: Text(r.name),
                  subtitle: Text('كمية: ${r.qty} | شراء: ${r.buy} | بيع: ${r.sell}'),
                  trailing: Text((r.qty * r.buy).toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          if (_rows.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _paid,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'المدفوع'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('الإجمالي: ${_total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ElevatedButton(
                        onPressed: _busy ? null : _save,
                        child: const Text('حفظ كفاتورة شراء'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
