import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'google_auth_config.dart';

/// Wraps Google Sign-In + Supabase Auth. Each signed-in Google account maps
/// to one Supabase user, and every shop's data is isolated per user (see the
/// RLS policies on the Supabase tables: `auth.uid() = user_id`).
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _googleSignIn = GoogleSignIn(
    serverClientId: GoogleAuthConfig.webClientId,
    scopes: const ['email'],
  );

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  sb.User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<sb.AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

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

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _client.auth.signOut();
  }
}
