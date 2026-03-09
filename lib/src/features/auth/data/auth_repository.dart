import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AppAuthException implements Exception {
  const AppAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _callbackScheme = 'storia';
  static const _callbackHost = 'login-callback';
  static const _callbackUrl = '$_callbackScheme://$_callbackHost/';

  supabase.Session? get currentSession => _client.auth.currentSession;

  Stream<supabase.AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  Future<void> sendMagicLink({
    required String email,
    required bool shouldCreateUser,
  }) async {
    try {
      await _client.auth.signInWithOtp(
        email: email,
        emailRedirectTo: _callbackUrl,
        shouldCreateUser: shouldCreateUser,
      );
    } catch (error) {
      if (error is supabase.AuthException) {
        throw AppAuthException(error.message);
      }
      throw AppAuthException(
        _messageFrom(error, 'Could not send a magic link right now.'),
      );
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      if (error is supabase.AuthException) {
        throw AppAuthException(error.message);
      }
      throw AppAuthException(_messageFrom(error, 'Could not sign out.'));
    }
  }

  Future<bool> signInWithOAuth(supabase.OAuthProvider provider) async {
    try {
      return await _client.auth.signInWithOAuth(
        provider,
        redirectTo: _callbackUrl,
      );
    } catch (error) {
      if (error is supabase.AuthException) {
        throw AppAuthException(error.message);
      }
      throw AppAuthException(
        _messageFrom(error, 'Could not start the social sign-in flow.'),
      );
    }
  }

  String _messageFrom(dynamic error, String fallback) {
    final message = error?.message;
    if (message is String && message.isNotEmpty) {
      return message;
    }
    return fallback;
  }
}
