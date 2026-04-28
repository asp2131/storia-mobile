import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_providers.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/auth/presentation/intro_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/child/data/child_profile_providers.dart';
import '../features/child/presentation/add_child_screen.dart';
import '../features/child/presentation/profile_picker_screen.dart';
import '../features/library/library_screen.dart';
import '../features/onboarding/data/app_review_flow_providers.dart';
import '../features/onboarding/presentation/parent_birth_year_screen.dart';
import '../features/onboarding/presentation/review_onboarding_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/settings/settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authStateNotifierProvider);
  final authState = ref.watch(authViewStateProvider);
  final appReviewNotifier = ref.watch(appReviewFlowNotifierProvider);
  final appReviewState = ref.watch(appReviewFlowProvider);
  final childProfileNotifier = ref.watch(childProfileRouterRefreshProvider);
  final activeChildProfileState = ref.watch(activeChildProfileIdStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: Listenable.merge([
      authNotifier,
      appReviewNotifier,
      childProfileNotifier,
    ]),
    redirect: (context, state) {
      final isAuthenticated =
          authState.isAuthenticated || appReviewState.hasReviewBypass;
      final needsParentBirthYear =
          appReviewState.hasReviewBypass && !appReviewState.hasParentBirthYear;
      final needsReviewOnboarding =
          appReviewState.hasReviewBypass &&
          appReviewState.hasParentBirthYear &&
          !appReviewState.hasCompletedOnboarding;
      final location = state.matchedLocation;
      const publicLocations = {'/', '/intro', '/sign-in', '/sign-up'};
      const profilePickerLocation = '/profiles/select';
      const addProfileLocation = '/profiles/new';
      final isProfilePicker = location == profilePickerLocation;
      final isAddProfile = location == addProfileLocation;
      final requiresBackendProfile = authState.isAuthenticated;
      final hasLoadedProfileSelection = activeChildProfileState.hasValue;
      final hasActiveChildProfile =
          activeChildProfileState.valueOrNull?.trim().isNotEmpty ?? false;

      if (!appReviewState.isReady) {
        return null;
      }

      if (location == '/') {
        if (!isAuthenticated) {
          return '/intro';
        }
        if (needsParentBirthYear) {
          return '/parent-birth-year';
        }
        if (requiresBackendProfile && !hasLoadedProfileSelection) {
          return null;
        }
        if (requiresBackendProfile && !hasActiveChildProfile) {
          return profilePickerLocation;
        }
        return needsReviewOnboarding ? '/onboarding' : '/library';
      }

      if (!isAuthenticated && !publicLocations.contains(location)) {
        return '/intro';
      }

      if (needsParentBirthYear && location != '/parent-birth-year') {
        return '/parent-birth-year';
      }

      if (needsReviewOnboarding && location != '/onboarding') {
        return '/onboarding';
      }

      if (requiresBackendProfile &&
          !needsParentBirthYear &&
          !needsReviewOnboarding &&
          hasLoadedProfileSelection &&
          !hasActiveChildProfile &&
          !isProfilePicker &&
          !isAddProfile) {
        return profilePickerLocation;
      }

      if (isAuthenticated &&
          !needsParentBirthYear &&
          !needsReviewOnboarding &&
          (location == '/intro' ||
              location == '/sign-in' ||
              location == '/sign-up' ||
              location == '/parent-birth-year' ||
              location == '/onboarding')) {
        if (requiresBackendProfile && !hasLoadedProfileSelection) {
          return null;
        }
        if (requiresBackendProfile && !hasActiveChildProfile) {
          return profilePickerLocation;
        }
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
        path: '/parent-birth-year',
        builder: (context, state) => const ParentBirthYearScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const ReviewOnboardingScreen(),
      ),
      GoRoute(
        path: '/profiles/select',
        builder: (context, state) => const ProfilePickerScreen(),
      ),
      GoRoute(
        path: '/profiles/new',
        builder: (context, state) => const AddChildScreen(),
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
