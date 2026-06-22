import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/aac_music_demo/presentation/aac_music_demo_screen.dart';
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
import 'journey/journey_policy.dart';
import 'journey/journey_providers.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Read stable notifier instances once. The GoRouter itself should not
  // rebuild on every auth/profile preference tick; the merged Listenable
  // below is what re-runs redirect with a fresh JourneySnapshot.
  final authNotifier = ref.read(authStateNotifierProvider);
  final appReviewNotifier = ref.read(appReviewFlowNotifierProvider);
  final childProfileNotifier = ref.read(childProfileRouterRefreshProvider);

  return GoRouter(
    initialLocation: JourneyRoutes.root,
    // Merge-list binding: every state source watched by
    // journeySnapshotProvider must have its notifier in this merge list,
    // or the redirect will not re-evaluate when that source changes.
    // See the doc comment on journeySnapshotProvider.
    refreshListenable: Listenable.merge([
      authNotifier,
      appReviewNotifier,
      childProfileNotifier,
    ]),
    // The journey truth table lives in JourneyPolicy (pure Dart, fully
    // table-tested in test/routing/journey/). `ref.read` (not watch):
    // refreshListenable already re-triggers redirect evaluation, and
    // reading at redirect time guarantees a fresh snapshot without
    // rebuilding the GoRouter itself.
    redirect: (context, state) => JourneyPolicy.redirect(
      ref.read(journeySnapshotProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: JourneyRoutes.root,
        builder: (context, state) => const AuthGateScreen(),
      ),
      GoRoute(
        path: JourneyRoutes.intro,
        builder: (context, state) => const IntroScreen(),
      ),
      GoRoute(
        path: JourneyRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: JourneyRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: JourneyRoutes.parentBirthYear,
        builder: (context, state) => const ParentBirthYearScreen(),
      ),
      GoRoute(
        path: JourneyRoutes.onboarding,
        builder: (context, state) => const ReviewOnboardingScreen(),
      ),
      GoRoute(
        path: JourneyRoutes.profilePicker,
        builder: (context, state) => const ProfilePickerScreen(),
      ),
      GoRoute(
        path: JourneyRoutes.addProfile,
        builder: (context, state) => const AddChildScreen(),
      ),
      GoRoute(
        path: JourneyRoutes.library,
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: JourneyRoutes.aacMusicDemo,
        builder: (context, state) => const AacMusicDemoScreen(),
      ),
      GoRoute(
        path: '/reader/:bookId',
        builder: (context, state) {
          final bookId = state.pathParameters['bookId'] ?? '';
          return ReaderScreen(bookId: bookId);
        },
      ),
      GoRoute(
        path: JourneyRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
