import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_providers.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/intro_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/library/library_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final isAuthenticated = authNotifier.isAuthenticated;
      final isRecoveryMode = authNotifier.isRecoveryMode;
      final location = state.matchedLocation;
      const publicLocations = {
        '/',
        '/intro',
        '/sign-in',
        '/sign-up',
        '/forgot-password',
      };

      if (location == '/') {
        if (isRecoveryMode) {
          return '/forgot-password?mode=update';
        }
        return isAuthenticated ? '/library' : '/intro';
      }

      if (isRecoveryMode && location != '/forgot-password') {
        return '/forgot-password?mode=update';
      }

      if (!isAuthenticated && !publicLocations.contains(location)) {
        return '/intro';
      }

      if (isAuthenticated &&
          (location == '/intro' ||
              location == '/sign-in' ||
              location == '/sign-up')) {
        return '/library';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const AuthGateScreen()),
      GoRoute(path: '/intro', builder: (context, state) => const IntroScreen()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) =>
            ForgotPasswordScreen(mode: state.uri.queryParameters['mode']),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/reader/:bookId',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId'] ?? '';
          return ReaderScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
