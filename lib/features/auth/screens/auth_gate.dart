import 'package:flutter/material.dart';

import '../../../core/sync/sync_service.dart';
import 'login_screen.dart';

/// Shows [child] once a Google account is signed in, otherwise [LoginScreen].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: SyncService.instance.auth.userIdChanges,
      builder: (context, snapshot) {
        final signedIn = SyncService.instance.auth.currentUserId != null;
        return signedIn ? child : const LoginScreen();
      },
    );
  }
}
