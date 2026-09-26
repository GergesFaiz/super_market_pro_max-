import 'package:flutter/material.dart';

import '../../../core/widgets/repository_scope.dart';
import '../../../domain/usecases/shop_stats.dart';

/// Reports: day / week / month / year stats + most profitable products.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

enum _Period { day, week, month, year }

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _period = _Period.month;
  bool _loading = true;
  ShopStats _stats = ShopStats.empty;
  List<ProductProfit> _profits = [];

  int _startFor(_Period p) {
    final now = DateTime.now();
    switch (p) {
      case _Period.day:
        return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      case _Period.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(start.year, start.month, start.day).millisecondsSinceEpoch;
      case _Period.month:
        return DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
      case _Period.year:
        return DateTime(now.year, 1, 1).millisecondsSinceEpoch;
    }
  }

  String get _label {
    switch (_period) {
      case _Period.day:
        return 'اليوم';
      case _Period.week:
        return 'الأسبوع';
      case _Period.month:
        return 'الشهر';
      case _Period.year:
        return 'السنة';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = RepositoryScope.of(context);
    final from = _startFor(_period);
    final to = DateTime.now().millisecondsSinceEpoch + 1;
    final invoices = await repo.getInvoicesInRange(from, to);
    final items = await repo.getSaleItemsInRange(from, to);
    if (!mounted) return;
    setState(() {
      _stats = computeStats(invoices: invoices, saleItems: items, fromMillis: from, toMillis: to);
      _profits = profitByProduct(items);
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير والأرباح')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<_Period>(
              segments: const [
                ButtonSegment(value: _Period.day, label: Text('يومي')),
                ButtonSegment(value: _Period.week, label: Text('أسبوعي')),
                ButtonSegment(value: _Period.month, label: Text('شهري')),
                ButtonSegment(value: _Period.year, label: Text('سنوي')),
              ],
              selected: {_period},
              onSelectionChanged: (s) {
                setState(() => _period = s.first);
                _load();
              },
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _card('مبيعات $_label', _stats.salesTotal, Colors.green),
                        _card('مشتريات $_label', _stats.purchasesTotal, Colors.orange),
                        _card('صافي الربح', _stats.profit, Colors.blue),
                        _card('فواتير البيع', _stats.salesCount.toDouble(), Colors.teal),
                        _card('آجل العملاء', _stats.unpaidSales, Colors.red),
                        _card('آجل الموردين', _stats.unpaidPurchases, Colors.brown),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('المنتجات الأكثر ربحاً',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ..._profits.map((p) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.monetization_on, color: Colors.green),
                            title: Text(p.name,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                'الكمية: ${p.qty} | الإيراد: ${p.revenue.toStringAsFixed(2)}'),
                            trailing: Text('+${p.profit.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.green, fontWeight: FontWeight.bold)),
                          ),
                        )),
                    if (_profits.isEmpty)
                      const Text('لا توجد مبيعات في هذه الفترة'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(String label, double value, Color color) {
    return SizedBox(
      width: 110,
      child: Card(
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Text(value.toStringAsFixed(value < 100 ? 1 : 0),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
