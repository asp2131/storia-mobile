import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loratone/src/features/auth/data/auth_providers.dart';
import 'package:loratone/src/features/auth/domain/auth_state.dart';
import 'package:loratone/src/features/child/data/child_profile_providers.dart';
import 'package:loratone/src/features/child/domain/child_profile.dart';
import 'package:loratone/src/features/onboarding/data/app_review_flow_providers.dart';
import 'package:loratone/src/routing/app_router.dart';
import 'package:loratone/src/routing/journey/journey_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session, User;

class _Auth extends ChangeNotifier implements AuthStateNotifier {
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
          id: 'parent',
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      ),
    );
    notifyListeners();
  }

  void signOut() {
    _state = const AuthViewState(session: null);
    notifyListeners();
  }
}

class _Selection extends ActiveChildProfileIdNotifier {
  _Selection(String? selected) : super(userId: 'parent') {
    state = AsyncValue.data(selected);
  }
  void select(String? id) => state = AsyncValue.data(id);
}

/// Uses the production parser, route table, delegate and refresh source. Only
/// widget construction is omitted, isolating router lifecycle from native media.
class _HeadlessDelegate extends RouterDelegate<RouteMatchList>
    with ChangeNotifier {
  _HeadlessDelegate(this.delegate) {
    delegate.addListener(notifyListeners);
  }
  final GoRouterDelegate delegate;
  @override
  RouteMatchList get currentConfiguration => delegate.currentConfiguration;
  @override
  Future<void> setNewRoutePath(RouteMatchList configuration) =>
      delegate.setNewRoutePath(configuration);
  @override
  Future<bool> popRoute() => delegate.popRoute();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
  @override
  void dispose() {
    delegate.removeListener(notifyListeners);
    super.dispose();
  }
}

const _profile = ChildProfile(
  id: 'child',
  displayName: 'Reader',
  ageBand: '4-6',
  isDefault: true,
);
const _review = AppReviewFlowState(
  isReady: true,
  hasReviewBypass: false,
  parentBirthYear: null,
  onboardingProfile: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<
    ({
      ProviderContainer container,
      GoRouter router,
      _Auth auth,
      _Selection selection,
      Future<void> Function() close,
    })
  >
  mount(WidgetTester tester, {String? selected}) async {
    final auth = _Auth();
    final selection = _Selection(selected);
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith((ref) => auth),
        appReviewFlowProvider.overrideWithValue(_review),
        activeChildProfileIdStateProvider.overrideWith((ref) => selection),
        childProfilesProvider.overrideWith((ref) async => const [_profile]),
      ],
    );
    final router = container.read(appRouterProvider);
    final delegate = _HeadlessDelegate(router.routerDelegate);
    var closed = false;
    Future<void> close() async {
      if (closed) return;
      closed = true;
      await tester.pumpWidget(const SizedBox.shrink());
      delegate.dispose();
      container.dispose();
    }

    addTearDown(close);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routeInformationProvider: router.routeInformationProvider,
          routeInformationParser: router.routeInformationParser,
          routerDelegate: delegate,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (
      container: container,
      router: router,
      auth: auth,
      selection: selection,
      close: close,
    );
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  testWidgets(
    'direct auth URL ignores a free-form protected return destination',
    (tester) async {
      final app = await mount(tester);
      app.router.go('${JourneyRoutes.signUp}?return=/reader/catalog-book');
      await tester.pumpAndSettle();
      expect(location(app.router), JourneyRoutes.signUp);
      await app.close();
    },
  );

  testWidgets('auth and child refresh advance the account journey', (
    tester,
  ) async {
    final app = await mount(tester);
    app.router.go(JourneyRoutes.signIn);
    await tester.pumpAndSettle();
    expect(location(app.router), JourneyRoutes.signIn);
    app.auth.signIn();
    await tester.pumpAndSettle();
    expect(location(app.router), JourneyRoutes.profilePicker);
    app.selection.select('child');
    app.router.go(JourneyRoutes.root);
    await tester.pumpAndSettle();
    expect(location(app.router), JourneyRoutes.library);
    await app.close();
  });

  testWidgets(
    'ordinary auth success with selected child goes directly to library',
    (tester) async {
      final app = await mount(tester, selected: 'child');
      app.router.go(JourneyRoutes.signIn);
      await tester.pumpAndSettle();
      app.auth.signIn();
      await tester.pumpAndSettle();
      expect(location(app.router), JourneyRoutes.library);
      await app.close();
    },
  );

  testWidgets(
    'signout redirects an authenticated reader away from the library',
    (tester) async {
      final app = await mount(tester, selected: 'child');
      app.auth.signIn();
      await tester.pumpAndSettle();
      app.auth.signOut();
      await tester.pumpAndSettle();
      expect(location(app.router), JourneyRoutes.intro);
      await app.close();
    },
  );

  testWidgets(
    'a missing celebration summary cannot open a signed-out library',
    (tester) async {
      final app = await mount(tester);
      app.router.go(JourneyRoutes.signIn);
      await tester.pumpAndSettle();
      app.router.go(JourneyRoutes.bookCelebration);
      await tester.pumpAndSettle();
      expect(location(app.router), JourneyRoutes.intro);
      await app.close();
    },
  );
}
