/// Identity provider boundary. The UI and the sync use cases only ever see
/// "is someone signed in, and what's their id/email" - never the specifics
/// of Google Sign-In or Supabase Auth.
abstract class AuthGateway {
  String? get currentUserId;
  String? get currentUserEmail;

  /// Emits the signed-in user's id, or null when signed out.
  Stream<String?> get userIdChanges;

  Future<void> signInWithGoogle();
  Future<void> signOut();
}
