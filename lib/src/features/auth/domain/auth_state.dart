import 'package:supabase_flutter/supabase_flutter.dart';

class AuthViewState {
  const AuthViewState({required this.session});

  final Session? session;

  bool get isAuthenticated => session != null;
}
