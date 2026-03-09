import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/providers.dart';
import '../domain/auth_state.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepository(client);
});

final authStateNotifierProvider = Provider<AuthStateNotifier>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final notifier = AuthStateNotifier(repository);
  ref.onDispose(notifier.dispose);
  return notifier;
});

class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._repository)
      : _state = AuthViewState(
          session: _repository.currentSession,
          isRecoveryMode: false,
          lastEvent: null,
        ) {
    _subscription = _repository.authStateChanges.listen(_handleAuthState);
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthState> _subscription;
  AuthViewState _state;

  AuthViewState get state => _state;
  bool get isAuthenticated => _state.isAuthenticated;
  bool get isRecoveryMode => _state.isRecoveryMode;

  void clearRecoveryMode() {
    if (!_state.isRecoveryMode) {
      return;
    }
    _state = AuthViewState(
      session: _state.session,
      isRecoveryMode: false,
      lastEvent: _state.lastEvent,
    );
    notifyListeners();
  }

  void _handleAuthState(AuthState authState) {
    _state = AuthViewState(
      session: authState.session,
      isRecoveryMode:
          authState.event == AuthChangeEvent.passwordRecovery ||
          (_state.isRecoveryMode && authState.session != null),
      lastEvent: authState.event,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
