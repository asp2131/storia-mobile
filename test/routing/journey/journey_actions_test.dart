// journey_actions: the thin ergonomic layer. The decision logic is covered
// by the pure-policy table tests; these tests pin only what the verbs
// themselves own — guard behavior, side-effect sequencing, and that each
// verb consults the policy instead of hardcoding destinations.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loratone/src/features/onboarding/data/app_review_flow_providers.dart';
import 'package:loratone/src/routing/journey/journey_actions.dart';
import 'package:loratone/src/routing/journey/journey_policy.dart';
import 'package:loratone/src/routing/journey/journey_providers.dart';

class _RecordingReviewNotifier extends AppReviewFlowNotifier {
  final List<String> calls = [];

  @override
  Future<void> clearReviewFlow() async {
    calls.add('clearReviewFlow');
  }
}

const _bypassNeedsBirthYear = JourneySnapshot(
  reviewFlowReady: true,
  hasSupabaseSession: false,
  hasReviewBypass: true,
  hasParentBirthYear: false,
  hasCompletedReviewOnboarding: false,
  profileSelection: ProfileSelection.none,
);

/// Minimal router with NO redirect: these tests exercise the verbs'
/// navigation directly, not the backstop.
GoRouter _router({String initial = '/start'}) {
  Widget page(String label) =>
      Scaffold(body: Center(child: Text('page:$label')));
  return GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: '/start', builder: (c, s) => page('start')),
      GoRoute(path: '/intro', builder: (c, s) => page('intro')),
      GoRoute(path: '/sign-in', builder: (c, s) => page('sign-in')),
      GoRoute(path: '/sign-up', builder: (c, s) => page('sign-up')),
      GoRoute(
        path: '/parent-birth-year',
        builder: (c, s) => page('parent-birth-year'),
      ),
      GoRoute(
        path: '/profiles/select',
        builder: (c, s) => page('profiles-select'),
      ),
      GoRoute(path: '/profiles/new', builder: (c, s) => page('profiles-new')),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('continueJourney', () {
    testWidgets('navigates to the policy nextLocation', (tester) async {
      final router = _router();
      late WidgetRef capturedRef;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journeySnapshotProvider.overrideWithValue(_bypassNeedsBirthYear),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Inject a Consumer into the current page via an overlay entry so
      // the verb gets a real (ref, context) below the router.
      final overlayState = tester.state<OverlayState>(find.byType(Overlay));
      overlayState.insert(
        OverlayEntry(
          builder: (overlayContext) => Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      continueJourney(capturedRef, capturedContext);
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/parent-birth-year',
      );
    });

    testWidgets('is a no-op when the context is unmounted', (tester) async {
      final router = _router();
      late WidgetRef capturedRef;
      late BuildContext capturedContext;
      final entry = OverlayEntry(
        builder: (_) => Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            capturedContext = context;
            return const SizedBox.shrink();
          },
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journeySnapshotProvider.overrideWithValue(_bypassNeedsBirthYear),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      tester.state<OverlayState>(find.byType(Overlay)).insert(entry);
      await tester.pumpAndSettle();

      entry.remove(); // unmount the Consumer that owns capturedContext
      await tester.pumpAndSettle();

      continueJourney(capturedRef, capturedContext); // must not throw
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/start',
        reason: 'unmounted context must not navigate',
      );
    });
  });

  group('restartJourney', () {
    testWidgets('clears the review flow BEFORE navigating to sign-in', (
      tester,
    ) async {
      final router = _router();
      // NOTE: no addTearDown(notifier.dispose) — ChangeNotifierProvider
      // (and the provider's own ref.onDispose) already dispose the
      // notifier; disposing again throws "used after being disposed".
      final notifier = _RecordingReviewNotifier();
      late WidgetRef capturedRef;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appReviewFlowNotifierProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      tester.state<OverlayState>(find.byType(Overlay)).insert(
        OverlayEntry(
          builder: (_) => Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/start',
      );

      await restartJourney(capturedRef, capturedContext);
      await tester.pumpAndSettle();

      expect(notifier.calls, ['clearReviewFlow']);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/sign-in',
      );
    });
  });

  group('backOutOfJourneyStep', () {
    testWidgets('sign-up backs out to intro', (tester) async {
      final router = _router(initial: '/sign-up');
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      backOutOfJourneyStep(tester.element(find.text('page:sign-up')));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/intro',
      );
    });

    testWidgets('add-profile backs out to the picker', (tester) async {
      final router = _router(initial: '/profiles/new');
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      backOutOfJourneyStep(tester.element(find.text('page:profiles-new')));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/profiles/select',
      );
    });
  });

  group('enterAuth / pushAddProfile', () {
    testWidgets('enterAuth switches between auth entry modes', (tester) async {
      final router = _router();
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      enterAuth(tester.element(find.text('page:start')), AuthEntry.signIn);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/sign-in',
      );

      enterAuth(tester.element(find.text('page:sign-in')), AuthEntry.signUp);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/sign-up',
      );
    });

    testWidgets('pushAddProfile pushes the add-profile sub-flow', (
      tester,
    ) async {
      final router = _router(initial: '/profiles/select');
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      pushAddProfile(tester.element(find.text('page:profiles-select')));
      await tester.pumpAndSettle();

      // context.push keeps the underlying URI in currentConfiguration;
      // assert on what is actually on screen: the pushed page on top.
      expect(find.text('page:profiles-new'), findsOneWidget);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/profiles/new',
      );
    });
  });
}
