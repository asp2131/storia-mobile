import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_client.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AuthUser? user;

  AuthState({required this.status, this.user});
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  final BetterAuthClient _client;
  final _controller = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get stream => _controller.stream;

  AuthStateNotifier(this._client)
      : super(AuthState(status: AuthStatus.unknown)) {
    checkSession();
  }

  void _updateState(AuthState newState) {
    state = newState;
    _controller.add(newState);
  }

  Future<void> checkSession() async {
    final hasToken = await _client.hasToken();
    if (!hasToken) {
      _updateState(AuthState(status: AuthStatus.unauthenticated));
      return;
    }

    // Token exists — authenticate immediately, then validate in background.
    if (state.status != AuthStatus.authenticated) {
      _updateState(AuthState(status: AuthStatus.authenticated, user: state.user));
    }

    try {
      final user = await _client.getSession();
      if (user != null) {
        _updateState(AuthState(status: AuthStatus.authenticated, user: user));
      } else {
        _updateState(AuthState(status: AuthStatus.unauthenticated));
      }
    } catch (_) {
      // Network error — keep authenticated since we have a stored token.
    }
  }

  Future<void> sendOtp(String email) async {
    await _client.sendOtp(email);
  }

  Future<void> verifyOtp(String email, String otp) async {
    final user = await _client.verifyOtp(email, otp);
    _updateState(AuthState(status: AuthStatus.authenticated, user: user));
  }

  Future<void> signOut() async {
    await _client.signOut();
    _updateState(AuthState(status: AuthStatus.unauthenticated));
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}

final betterAuthClientProvider = Provider<BetterAuthClient>((ref) {
  return BetterAuthClient();
});

final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  final client = ref.watch(betterAuthClientProvider);
  return AuthStateNotifier(client);
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authStateProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).status == AuthStatus.authenticated;
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
