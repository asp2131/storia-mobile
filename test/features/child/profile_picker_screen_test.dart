import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/auth/data/auth_providers.dart';
import 'package:loratone/src/features/auth/domain/auth_state.dart';
import 'package:loratone/src/features/child/data/child_profile_providers.dart';
import 'package:loratone/src/features/child/domain/child_profile.dart';
import 'package:loratone/src/features/child/presentation/profile_picker_screen.dart';
import 'package:loratone/src/features/onboarding/data/app_review_flow_providers.dart';
import 'package:loratone/src/features/onboarding/data/entry_flow_provider.dart';
import 'package:loratone/src/features/onboarding/domain/entry_flow_state.dart';
import 'package:loratone/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session, User;

class _Auth extends ChangeNotifier implements AuthStateNotifier {
  @override
  AuthViewState get state => AuthViewState(
    session: Session(
      accessToken: 'token',
      tokenType: 'bearer',
      user: User(
        id: 'parent',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00.000Z',
      ),
    ),
  );
  @override
  bool get isAuthenticated => true;
}

void main() {
  for (final changeReader in [false, true]) {
    testWidgets(
      'pending save requires explicit ${changeReader ? 'new reader selection' : 'confirmation of preselected reader'}',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'activeChildProfileId.parent': 'child-a',
        });
        final entry = EntryFlowNotifier();
        await entry.ready;
        entry.beginParentEntry(EntryAuthIntent.signIn, saveSample: true);
        entry.authorizeParentAfterPassedGate();
        entry.verifyAdultYear(DateTime.now().year - 30);
        final review = AppReviewFlowNotifier();
        await review.ready;
        final container = ProviderContainer(
          overrides: [
            entryFlowNotifierProvider.overrideWith((ref) {
              ref.onDispose(entry.dispose);
              return entry;
            }),
            authStateNotifierProvider.overrideWith((ref) => _Auth()),
            appReviewFlowNotifierProvider.overrideWith((ref) => review),
            childProfilesProvider.overrideWith(
              (ref) async => [
                const ChildProfile(
                  id: 'child-a',
                  userId: 'parent',
                  displayName: 'Reader A',
                  ageBand: '7-9',
                  isDefault: true,
                ),
                const ChildProfile(
                  id: 'child-b',
                  userId: 'parent',
                  displayName: 'Reader B',
                  ageBand: '3-4',
                  isDefault: false,
                ),
              ],
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(childProfilesProvider.future);
        // Keep the real account-scoped selection preference implementation.
        await container.read(activeChildProfileIdStateProvider.notifier).load();
        final router = container.read(appRouterProvider);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePickerScreen), findsOneWidget);
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/profiles/select',
        );
        expect(entry.state.pendingSampleSave, isNotNull);
        final action = find.text(
          changeReader ? 'Reader B' : 'Continue with Reader A',
        );
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          container.read(activeChildProfileIdProvider),
          changeReader ? 'child-b' : 'child-a',
        );
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/save-story',
        );
        // Choosing the recipient is not itself the claim confirmation.
        expect(entry.state.pendingSampleSave, isNotNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
}
