import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/data/shop_repository.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/repository_scope.dart';
import 'features/backup/screens/backup_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';import 'features/inventory/cubit/inventory_cubit.dart';
import 'features/inventory/screens/inventory_screen.dart';
import 'features/invoices/cubit/invoices_cubit.dart';
import 'features/invoices/screens/invoice_list_screen.dart';
import 'features/expenses/screens/expenses_screen.dart';
import 'features/parties/cubit/parties_cubit.dart';
import 'features/parties/screens/parties_screen.dart';
import 'features/reports/screens/reports_screen.dart';
import 'features/settings/screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SuperMarketProMax());
}

class SuperMarketProMax extends StatelessWidget {
  const SuperMarketProMax({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ShopRepository();
    return RepositoryScope(
      repository: repo,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => InventoryCubit(repo)..load()),
          BlocProvider(create: (_) => InvoicesCubit(repo)),
          BlocProvider(create: (_) => PartiesCubit(repo)),
        ],
        child: MaterialApp(
          title: 'Super Market Pro Max',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const MainShell(),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _go(int i) {
    final invoices = context.read<InvoicesCubit>();
    final parties = context.read<PartiesCubit>();
    if (i == 2) invoices.loadHistory('sale');
    if (i == 3) invoices.loadHistory('purchase');
    if (i == 4) parties.load('customer');
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardScreen(),
      const InventoryScreen(),
      const InvoiceListScreen(kind: 'sale'),
      const InvoiceListScreen(kind: 'purchase'),
      const MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.inventory), label: 'المخزن'),
          NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'بيع'),
          NavigationDestination(icon: Icon(Icons.shopping_bag), label: 'شراء'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'المزيد'),
        ],
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final parties = context.read<PartiesCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('المزيد')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.people, color: Colors.blue),
            title: const Text('العملاء'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              parties.load('customer');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PartiesScreen(kind: 'customer')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping, color: Colors.orange),
            title: const Text('الموردون'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              parties.load('supplier');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PartiesScreen(kind: 'supplier')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart, color: Colors.purple),
            title: const Text('التقارير والأرباح'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.store, color: Colors.teal),
            title: const Text('بيانات المحل واللوجو'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.money_off, color: Colors.red),
            title: const Text('المصاريف'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensesScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup, color: Colors.green),
            title: const Text('نسخ احتياطي / استرجاع'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              );
            },
          ),
          const AboutListTile(
            applicationName: 'Super Market Pro Max',
            applicationVersion: '1.0.0',
            aboutBoxChildren: [Text('إدارة محلات: مبيعات، مشتريات، مخزن، عملاء وموردون، تقارير وأرباح — يعمل بدون إنترنت.')],
          ),
        ],
      ),
    );
  }
}
