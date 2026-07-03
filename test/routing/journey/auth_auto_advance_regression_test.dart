// REGRESSION GUARD for the deleted screen-side auto-advance listeners.
//
// sign_in_screen and sign_up_screen used to carry a ref.listen on auth
// state that hand-navigated to '/library' after sign-in (hardcoding the
// destination and skipping the profile-picker gate). Those listeners were
// deleted in issue #33 Phase 4; post-auth advancement is now owned entirely
// by the router redirect backstop: auth notifier fires -> refreshListenable
// pings -> JourneyPolicy.redirect moves the user off the auth screen.
//
// This test pins that mechanism. The harness router mirrors the production
// wiring in app_router.dart EXACTLY (same redirect delegation, same
// refreshListenable merge topology, same snapshot provider) but uses stub
// pages so the test does not drag Supabase-backed screens into scope. If
// you change the wiring in app_router.dart, change it here too.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loratone/src/features/auth/data/auth_providers.dart';
import 'package:loratone/src/features/auth/domain/auth_state.dart';
import 'package:loratone/src/features/child/data/child_profile_providers.dart';
import 'package:loratone/src/features/child/domain/child_profile.dart';
import 'package:loratone/src/features/onboarding/data/app_review_flow_providers.dart';
import 'package:loratone/src/routing/journey/journey_policy.dart';
import 'package:loratone/src/routing/journey/journey_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session, User;

class _FakeAuthNotifier extends ChangeNotifier implements AuthStateNotifier {
  AuthViewState _state = const AuthViewState(session: null);

  @override
  AuthViewState get state => _state;

  @override
  bool get isAuthenticated => _state.isAuthenticated;

  void signIn() {
    _state = AuthViewState(
      session: Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: User(
          id: 'user-1',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00.000Z',
        ),
      ),
    );
    notifyListeners();
  }
}

class _FakeActiveChildProfileIdNotifier extends ActiveChildProfileIdNotifier {
  _FakeActiveChildProfileIdNotifier(AsyncValue<String?> initial)
    : super(userId: 'user-1') {
    state = initial;
  }

  void emit(AsyncValue<String?> next) => state = next;
}

const _readyNoBypass = AppReviewFlowState(
  isReady: true,
  hasReviewBypass: false,
  parentBirthYear: null,
  onboardingProfile: null,
);

/// Mirrors appRouterProvider's production wiring with stub pages: read stable
/// notifier instances once, then let refreshListenable re-run redirect with a
/// fresh JourneySnapshot on every auth/profile/app-review tick.
final _testRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(authStateNotifierProvider);
  final appReviewNotifier = ref.read(appReviewFlowNotifierProvider);
  final childProfileNotifier = ref.read(childProfileRouterRefreshProvider);

  Widget page(String label) =>
      Scaffold(body: Center(child: Text('page:$label')));

  return GoRouter(
    initialLocation: JourneyRoutes.signIn,
    refreshListenable: Listenable.merge([
      authNotifier,
      appReviewNotifier,
      childProfileNotifier,
    ]),
    redirect: (context, state) => JourneyPolicy.redirect(
      ref.read(journeySnapshotProvider),
      state.matchedLocation,
    ),
    routes: [
      GoRoute(path: JourneyRoutes.root, builder: (c, s) => page('gate')),
      GoRoute(path: JourneyRoutes.intro, builder: (c, s) => page('intro')),
      GoRoute(path: JourneyRoutes.signIn, builder: (c, s) => page('sign-in')),
      GoRoute(path: JourneyRoutes.signUp, builder: (c, s) => page('sign-up')),
      GoRoute(
        path: JourneyRoutes.profilePicker,
        builder: (c, s) => page('profiles-select'),
      ),
      GoRoute(path: JourneyRoutes.library, builder: (c, s) => page('library')),
    ],
  );
});

void main() {
  Future<
    ({
      GoRouter router,
      _FakeAuthNotifier auth,
      ChildProfileRouterRefreshNotifier childRefresh,
    })
  >
  pumpApp(
    WidgetTester tester, {
    required AsyncValue<String?> profileSelection,
    _FakeActiveChildProfileIdNotifier? profileNotifier,
    ChildProfileRouterRefreshNotifier? childRefreshNotifier,
  }) async {
    final auth = _FakeAuthNotifier();
    final childRefresh =
        childRefreshNotifier ?? ChildProfileRouterRefreshNotifier();
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith((ref) => auth),
        // Override the notifier itself too. The production provider registers
        // ref.onDispose(notifier.dispose) even though ChangeNotifierProvider
        // already disposes it; using a plain override avoids surfacing that
        // unrelated known double-dispose issue in this focused regression.
        appReviewFlowNotifierProvider.overrideWith(
          (ref) => AppReviewFlowNotifier(),
        ),
        appReviewFlowProvider.overrideWithValue(_readyNoBypass),
        activeChildProfileIdStateProvider.overrideWith(
          (ref) =>
              profileNotifier ??
              _FakeActiveChildProfileIdNotifier(profileSelection),
        ),
        childProfileRouterRefreshProvider.overrideWith((ref) => childRefresh),
        // The real childProfileRouterRefreshProvider listens to this; pin
        // it so the post-auth rebuild never touches Supabase in tests.
        childProfilesProvider.overrideWith((ref) async => <ChildProfile>[]),
      ],
    );
    addTearDown(container.dispose);

    final router = container.read(_testRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return (router: router, auth: auth, childRefresh: childRefresh);
  }

  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets(
    'auth flip on /sign-in advances to /profiles/select via the backstop '
    '(no screen listener, no /library double hop)',
    (tester) async {
      final app = await pumpApp(
        tester,
        profileSelection: const AsyncValue.data(null), // loaded, none active
      );
      expect(locationOf(app.router), '/sign-in');

      app.auth.signIn();
      await tester.pumpAndSettle();

      expect(
        locationOf(app.router),
        '/profiles/select',
        reason: 'must gate on the picker, not hop through /library',
      );
      expect(find.text('page:profiles-select'), findsOneWidget);
    },
  );

  testWidgets(
    'auth flip with an active profile advances straight to /library',
    (tester) async {
      final app = await pumpApp(
        tester,
        profileSelection: const AsyncValue.data('child-1'),
      );
      expect(locationOf(app.router), '/sign-in');

      app.auth.signIn();
      await tester.pumpAndSettle();

      expect(locationOf(app.router), '/library');
      expect(find.text('page:library'), findsOneWidget);
    },
  );

  testWidgets(
    'auth flip while profile selection is loading holds on /sign-in, then '
    'advances when selection resolves (childProfileRouterRefresh ping)',
    (tester) async {
      final profileNotifier = _FakeActiveChildProfileIdNotifier(
        const AsyncValue.loading(),
      );
      final app = await pumpApp(
        tester,
        profileSelection: const AsyncValue.loading(),
        profileNotifier: profileNotifier,
      );

      app.auth.signIn();
      await tester.pumpAndSettle();
      expect(
        locationOf(app.router),
        '/sign-in',
        reason: 'loading selection must stay put, never flicker',
      );

      // Selection resolves; ping the same notifier that production wires
      // into refreshListenable so redirect re-evaluates against the fresh
      // snapshot.
      profileNotifier.emit(const AsyncValue.data(null));
      app.childRefresh.refresh();
      await tester.pumpAndSettle();

      expect(locationOf(app.router), '/profiles/select');
    },
  );
}
