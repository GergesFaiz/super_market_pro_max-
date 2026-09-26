import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/auth/auth_service.dart';
import '../../../core/data/shop_repository.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/widgets/repository_scope.dart';

/// Backup: export all data as JSON (copy it) or import pasted JSON, plus the
/// cloud sync status for the signed-in account.
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

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هتقدر ترجع تسجل دخول بنفس الحساب في أي وقت وتستعيد بياناتك.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تسجيل الخروج')),
        ],
      ),
    );
    if (confirmed == true) {
      await AuthService.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositoryScope.of(context);
    final email = sb.Supabase.instance.client.auth.currentUser?.email ?? '';
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
          const Divider(height: 32),
          const Text('3) المزامنة السحابية',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('الحساب المسجّل: $email'),
          const SizedBox(height: 8),
          const Text(
            'كل مرة الجهاز يتصل بالإنترنت، بياناتك بترفع تلقائيًا لحساب جوجل بتاعك، وبياناتك مستقلة تمامًا عن أي حساب تاني.',
          ),
          const SizedBox(height: 8),
          StreamBuilder<SyncStatus>(
            stream: SyncService.instance.statusStream,
            builder: (context, snapshot) {
              final status = snapshot.data ?? SyncService.instance.status;
              final text = switch (status) {
                SyncStatus.syncing => 'جاري رفع البيانات...',
                SyncStatus.error =>
                  'فشلت آخر محاولة مزامنة (سيُعاد المحاولة تلقائيًا)',
                SyncStatus.signedOut => 'غير مسجّل دخول',
                SyncStatus.idle => SyncService.instance.lastSyncedAt != null
                    ? 'آخر مزامنة: ${SyncService.instance.lastSyncedAt}'
                    : 'لم تتم المزامنة بعد',
              };
              return Row(
                children: [
                  Icon(
                    status == SyncStatus.error
                        ? Icons.cloud_off
                        : Icons.cloud_done,
                    color:
                        status == SyncStatus.error ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text)),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => SyncService.instance.syncNow(),
            icon: const Icon(Icons.sync),
            label: const Text('مزامنة الآن'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
