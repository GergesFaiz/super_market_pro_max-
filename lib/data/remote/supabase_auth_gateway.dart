import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/repositories/auth_gateway.dart';
import 'google_auth_config.dart';

/// [AuthGateway] backed by Google Sign-In + Supabase Auth. Every signed-in
/// Google account maps to one Supabase user, and every shop's data is
/// isolated per user (see the RLS policies on the Supabase tables:
/// `auth.uid() = user_id`).
class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway()
      : _googleSignIn = GoogleSignIn(
          serverClientId: GoogleAuthConfig.webClientId,
          scopes: const ['email'],
        );
  final GoogleSignIn _googleSignIn;

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  Stream<String?> get userIdChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user.id);

  @override
  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('تم إلغاء تسجيل الدخول');
    }
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw Exception('لم يتم الحصول على بيانات جوجل، حاول مرة أخرى');
    }
    await _client.auth.signInWithIdToken(
      provider: sb.OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _client.auth.signOut();
  }
}
