import 'package:flutter/material.dart';

import '../../../core/sync/sync_service.dart';

/// Shown when no account is signed in. Signing in with Google isolates each
/// shop's data (via the Google account) and enables automatic cloud backup.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await SyncService.instance.auth.signInWithGoogle();
      final isDifferentAccount =
          await SyncService.instance.isDifferentAccountThanBefore();
      var wipeLocalFirst = false;
      if (isDifferentAccount && mounted) {
        wipeLocalFirst = await _askWipeLocalData();
      }
      await SyncService.instance.onSignedIn(wipeLocalFirst: wipeLocalFirst);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل تسجيل الدخول: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _askWipeLocalData() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('حساب مختلف على هذا الجهاز'),
        content: const Text(
          'الجهاز ده كان عليه بيانات محل تاني. تحب تمسح البيانات المحلية وتبدأ بحساب المحل الجديد نظيف، ولا تدمجها مع بيانات هذا الحساب؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('دمج البيانات'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح والبدء من جديد'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storefront, size: 72, color: Colors.teal),
              const SizedBox(height: 16),
              const Text('Super Market Pro Max',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'سجّل دخولك بحساب جوجل عشان بياناتك تترفع وترجع تلقائيًا لو ضاع الجهاز، وكل حساب بياناته مستقلة تمامًا.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _busy
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _signIn,
                      icon: const Icon(Icons.login),
                      label: const Text('تسجيل الدخول بجوجل'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
