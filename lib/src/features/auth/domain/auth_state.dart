import 'package:supabase_flutter/supabase_flutter.dart';

class AuthViewState {
  const AuthViewState({
    required this.session,
    required this.isRecoveryMode,
    required this.lastEvent,
  });

  final Session? session;
  final bool isRecoveryMode;
  final AuthChangeEvent? lastEvent;

  bool get isAuthenticated => session != null;
}
