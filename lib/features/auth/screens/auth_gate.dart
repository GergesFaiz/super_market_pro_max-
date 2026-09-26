import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'login_screen.dart';

/// Shows [child] once a Google account is signed in, otherwise [LoginScreen].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<sb.AuthState>(
      stream: sb.Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final signedIn =
            sb.Supabase.instance.client.auth.currentUser != null;
        return signedIn ? child : const LoginScreen();
      },
    );
  }
}
