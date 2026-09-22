import 'package:flutter/material.dart';

import '../../../core/data/shop_repository.dart';
import '../../../core/logic/shop_stats.dart';
import '../../../core/models/shop_models.dart';
import '../../../core/widgets/repository_scope.dart';

/// Home dashboard: today + month stats, top sellers, low stock alerts.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ShopStats _today = ShopStats.empty;
  ShopStats _month = ShopStats.empty;
  List<MapEntry<String, double>> _top = [];
  List<Product> _low = [];
  bool _loading = true;

  int _startOfDay() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
  }

  int _startOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
  }

  Future<void> _load(ShopRepository repo) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dayStart = _startOfDay();
    final monthStart = _startOfMonth();
    final dayInv = await repo.getInvoicesInRange(dayStart, now + 1);
    final monthInv = await repo.getInvoicesInRange(monthStart, now + 1);
    final dayItems = await repo.getSaleItemsInRange(dayStart, now + 1);
    final monthItems = await repo.getSaleItemsInRange(monthStart, now + 1);
    final low = await repo.lowStock(5);
    if (!mounted) return;
    setState(() {
      _today = computeStats(invoices: dayInv, saleItems: dayItems, fromMillis: dayStart, toMillis: now + 1);
      _month = computeStats(invoices: monthInv, saleItems: monthItems, fromMillis: monthStart, toMillis: now + 1);
      _top = topSelling(monthItems);
      _low = low;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة المحل')),
      body: Builder(
        builder: (context) {
          if (_loading) {
            _load(repo);
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: () => _load(repo),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _section('اليوم', [
                  _tile('مبيعات اليوم', _today.salesTotal, Colors.green, Icons.point_of_sale),
                  _tile('مشتريات اليوم', _today.purchasesTotal, Colors.orange, Icons.shopping_bag),
                  _tile('ربح اليوم', _today.profit, Colors.blue, Icons.trending_up),
                ]),
                _section('الشهر', [
                  _tile('مبيعات الشهر', _month.salesTotal, Colors.green, Icons.calendar_month),
                  _tile('أرباح الشهر', _month.profit, Colors.blue, Icons.attach_money),
                  _tile('آجل العملاء', _month.unpaidSales, Colors.red, Icons.warning),
                ]),
                const SizedBox(height: 8),
                const Text('الأكثر مبيعاً (الشهر)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ..._top.map((e) => ListTile(
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: Text(e.key),
                      trailing: Text('${e.value} قطعة'),
                    )),
                if (_top.isEmpty) const Text('لا توجد مبيعات بعد'),
                const SizedBox(height: 8),
                const Text('تنبيهات المخزون (5 أو أقل)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ..._low.map((p) => ListTile(
                      leading: const Icon(Icons.inventory, color: Colors.red),
                      title: Text(p.name),
                      trailing: Text('${p.quantity}'),
                    )),
                if (_low.isEmpty) const Text('المخزون سليم'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.85,
          children: cards,
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _tile(String label, double value, Color color, IconData icon) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 4),
            Text(value.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
