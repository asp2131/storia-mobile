// REGRESSION GUARD: auth flip must not re-enter journeySnapshotProvider.
//
// Chain that used to throw ConcurrentModificationError on web sign-in:
//   auth notify -> router redirect -> ref.read(journeySnapshotProvider)
//   -> flush walks its dependency map -> activeChildProfileIdStateProvider
//   rebuilds -> childProfileRouterRefreshProvider's ref.listen fires
//   -> refresh() notified the router SYNCHRONOUSLY -> redirect re-reads
//   journeySnapshotProvider mid-iteration -> map mutated -> crash.
//
// Uses the REAL activeChildProfileIdStateProvider and
// childProfileRouterRefreshProvider (the auto-advance regression test
// overrides both, which is why it never caught this).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/auth/data/auth_providers.dart';
import 'package:loratone/src/features/auth/domain/auth_state.dart';
import 'package:loratone/src/features/child/data/child_profile_providers.dart';
import 'package:loratone/src/features/child/domain/child_profile.dart';
import 'package:loratone/src/features/onboarding/data/app_review_flow_providers.dart';
import 'package:loratone/src/routing/journey/journey_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('auth flip does not re-enter journeySnapshotProvider', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = _FakeAuthNotifier();
    final container = ProviderContainer(
      overrides: [
        authStateNotifierProvider.overrideWith((ref) => auth),
        appReviewFlowNotifierProvider.overrideWith(
          (ref) => AppReviewFlowNotifier(),
        ),
        childProfilesProvider.overrideWith((ref) async => <ChildProfile>[]),
      ],
    );
    addTearDown(container.dispose);

    // Mirror app_router.dart: read stable notifiers, merge them, and read
    // the snapshot synchronously on every tick (what redirect does).
    final refresh = Listenable.merge([
      container.read(authStateNotifierProvider),
      container.read(appReviewFlowNotifierProvider),
      container.read(childProfileRouterRefreshProvider),
    ]);
    container.read(journeySnapshotProvider);
    await Future<void>.delayed(Duration.zero); // let initial load() settle

    Object? error;
    refresh.addListener(() {
      try {
        container.read(journeySnapshotProvider);
      } catch (e) {
        error = e;
      }
    });

    auth.signIn();
    await Future<void>.delayed(Duration.zero);

    expect(error, isNull);
    expect(container.read(journeySnapshotProvider).hasSupabaseSession, isTrue);
  });
}
