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

final authStateNotifierProvider = ChangeNotifierProvider<AuthStateNotifier>((
  ref,
) {
  final repository = ref.watch(authRepositoryProvider);
  final notifier = AuthStateNotifier(repository);
  ref.onDispose(notifier.dispose);
  return notifier;
});

final authViewStateProvider = Provider<AuthViewState>((ref) {
  final notifier = ref.watch(authStateNotifierProvider);
  return notifier.state;
});

class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._repository)
    : _state = AuthViewState(session: _repository.currentSession) {
    _subscription = _repository.authStateChanges.listen(_handleAuthState);
  }

  final AuthRepository _repository;
  late final StreamSubscription<AuthState> _subscription;
  AuthViewState _state;

  AuthViewState get state => _state;
  bool get isAuthenticated => _state.isAuthenticated;

  void _handleAuthState(AuthState authState) {
    _state = AuthViewState(session: authState.session);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
