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

  /// Completes an email sign-in with the 6-digit code from the same email that
  /// carries the magic link.
  ///
  /// Why this exists: the link alone is unreliable. It can be consumed by an
  /// inbox security scanner before the human taps it, or opened in a browser
  /// that never had the PKCE code verifier — in both cases Supabase marks the
  /// address confirmed while the device never receives a session. Production
  /// data showed several signups stuck exactly there (`email_confirmed_at` set,
  /// `last_sign_in_at` null). Typing the code needs no deep link at all, and
  /// works when the mail is read on another device.
  Future<void> verifyEmailCode({
    required String email,
    required String code,
    required bool isSignUp,
  }) async {
    // GoTrue derives the OTP type from whichever template sent the code: a
    // brand-new account gets "Confirm signup" (signup) and an existing one gets
    // "Magic Link" (email). The caller can't know which fired, so try the more
    // likely one first and fall back once.
    final types = isSignUp
        ? const [supabase.OtpType.signup, supabase.OtpType.email]
        : const [supabase.OtpType.email, supabase.OtpType.signup];

    Object? lastError;

    for (final type in types) {
      try {
        await _client.auth.verifyOTP(email: email, token: code, type: type);
        return;
      } catch (error) {
        lastError = error;
      }
    }

    if (lastError is supabase.AuthException) {
      throw AppAuthException(lastError.message);
    }
    throw AppAuthException(
      _messageFrom(lastError, 'That code did not work. Request a new one.'),
    );
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
