import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/shop_repository.dart';
import '../../../core/widgets/repository_scope.dart';

/// Backup: export all data as JSON (copy it) or import pasted JSON.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String _exported = '';
  final _importCtrl = TextEditingController();
  bool _busy = false;

  Future<void> _doExport(ShopRepository repo) async {
    setState(() => _busy = true);
    try {
      final json = await repo.exportJson();
      setState(() => _exported = json);
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم نسخ النسخة الاحتياطية. احفظها في مكان آمن')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doImport(ShopRepository repo) async {
    if (_importCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await repo.importJson(_importCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استرجاع البيانات بنجاح')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ملف غير صالح')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    // Reuse the scope defined in dashboard to avoid a new dependency.
    return Scaffold(
      appBar: AppBar(title: const Text('نسخ احتياطي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
                const Text('1) أخذ نسخة: اضغط الزر ثم احفظ النص المنسوخ في ملف.',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _doExport(repo),
                  icon: const Icon(Icons.backup),
                  label: const Text('نسخ احتياطي الآن'),
                ),
                if (_exported.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('حجم النسخة: ${_exported.length} حرف',
                      style: const TextStyle(color: Colors.grey)),
                ],
                const Divider(height: 32),
                const Text('2) استرجاع: الصق نص النسخة هنا واضغط استرجاع.',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _importCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(hintText: 'الصق JSON هنا...'),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _doImport(repo),
                  icon: const Icon(Icons.restore),
                  label: const Text('استرجاع البيانات'),
                ),
              ],
      ),
    );
  }
}
