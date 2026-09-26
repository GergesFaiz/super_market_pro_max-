/// Google Sign-In configuration.
///
/// You must create this yourself in Google Cloud Console (see setup steps
/// given separately) and paste the Web client id below. It is required for
/// both Android and iOS even though it's a "Web" client - it's what lets
/// Supabase verify the Google identity token.
class GoogleAuthConfig {
  static const webClientId =
      'PASTE_YOUR_GOOGLE_WEB_CLIENT_ID.apps.googleusercontent.com';
}
