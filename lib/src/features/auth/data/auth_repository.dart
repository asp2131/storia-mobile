import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  Future<void> signInWithNativeApple() async {
    try {
      final rawNonce = _generateRawNonce();
      final hashedNonce = _sha256OfString(rawNonce);
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AppAuthException(
          'Could not get an Apple identity token from this device.',
        );
      }

      await _client.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      switch (error.code) {
        case AuthorizationErrorCode.canceled:
          throw const AppAuthException('Apple sign-in was canceled.');
        case AuthorizationErrorCode.failed:
        case AuthorizationErrorCode.notHandled:
        case AuthorizationErrorCode.credentialExport:
        case AuthorizationErrorCode.credentialImport:
        case AuthorizationErrorCode.matchedExcludedCredential:
          throw const AppAuthException(
            'Apple sign-in failed. Verify Sign in with Apple is enabled for this app and that this device is signed into an Apple ID.',
          );
        case AuthorizationErrorCode.invalidResponse:
          throw const AppAuthException(
            'Apple returned an invalid auth response. Please try again.',
          );
        case AuthorizationErrorCode.notInteractive:
          throw const AppAuthException(
            'Apple sign-in is not interactive right now. Try again when the app is active.',
          );
        case AuthorizationErrorCode.unknown:
          throw AppAuthException(
            _messageFrom(error, 'Could not complete Apple sign-in right now.'),
          );
      }
    } catch (error) {
      if (error is supabase.AuthException) {
        throw AppAuthException(error.message);
      }
      if (error is AppAuthException) {
        rethrow;
      }
      throw AppAuthException(
        _messageFrom(error, 'Could not complete Apple sign-in right now.'),
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

  String _generateRawNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
