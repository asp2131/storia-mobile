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

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (error) {
      if (error is supabase.AuthException) {
        throw AppAuthException(error.message);
      }
      throw AppAuthException(
        _messageFrom(error, 'Could not sign in right now.'),
      );
    }
  }

  Future<supabase.AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _callbackUrl,
      );
    } catch (error) {
      if (error is supabase.AuthException) {
        throw AppAuthException(error.message);
      }
      throw AppAuthException(
        _messageFrom(error, 'Could not create the account right now.'),
      );
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email, redirectTo: _callbackUrl);
    } catch (error) {
      if (error is supabase.AuthException) {
        throw AppAuthException(error.message);
      }
      throw AppAuthException(
        _messageFrom(error, 'Could not send the reset email.'),
      );
    }
  }

  Future<void> updatePassword(String password) async {
    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(password: password),
      );
    } catch (error) {
      if (error is supabase.AuthException) {
        throw AppAuthException(error.message);
      }
      throw AppAuthException(
        _messageFrom(error, 'Could not update the password.'),
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
