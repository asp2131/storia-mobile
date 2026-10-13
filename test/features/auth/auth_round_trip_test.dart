import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/auth/domain/auth_state.dart';
import 'package:loratone/src/features/child/data/child_profile_providers.dart';
import 'package:loratone/src/features/onboarding/data/app_review_flow_providers.dart';
import 'package:loratone/src/features/onboarding/presentation/review_onboarding_screen.dart';
import 'package:loratone/src/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loratone/src/features/auth/data/auth_providers.dart';
import 'package:loratone/src/features/auth/data/auth_repository.dart';
import 'package:loratone/src/features/auth/presentation/sign_in_screen.dart';
import 'package:loratone/src/features/auth/presentation/sign_up_screen.dart';
import 'package:loratone/src/features/onboarding/data/entry_flow_provider.dart';
import 'package:loratone/src/features/onboarding/domain/entry_flow_state.dart';

class _MailRepository implements AuthRepository {
  Object? sendError;
  Object? verifyError;
  String? sentEmail;
  String? verifiedCode;
  bool? createsUser;

  @override
  Future<void> sendMagicLink({
    required String email,
    required bool shouldCreateUser,
  }) async {
    sentEmail = email;
    createsUser = shouldCreateUser;
    if (sendError != null) throw sendError!;
  }

  @override
  Future<void> verifyEmailCode({
    required String email,
    required String code,
    required bool isSignUp,
  }) async {
    verifiedCode = code;
    if (verifyError != null) throw verifyError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedOut extends ChangeNotifier implements AuthStateNotifier {
  @override
  AuthViewState get state => const AuthViewState(session: null);
  @override
  bool get isAuthenticated => false;
}

void main() {
  testWidgets(
    'review signup copies the active year without another gate or backend auth',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'app_review_parent_birth_year': 1970,
      });
      final entry = EntryFlowNotifier();
      await entry.ready;
      entry.beginParentEntry(EntryAuthIntent.signUp);
      entry.authorizeParentAfterPassedGate();
      final verifiedYear = DateTime.now().year - 30;
      entry.verifyAdultYear(verifiedYear);
      final review = AppReviewFlowNotifier();
      await review.ready;
      final container = ProviderContainer(
        overrides: [
          entryFlowNotifierProvider.overrideWith((ref) {
            ref.onDispose(entry.dispose);
            return entry;
          }),
          appReviewFlowNotifierProvider.overrideWith((ref) => review),
          authStateNotifierProvider.overrideWith((ref) => _SignedOut()),
          authRepositoryProvider.overrideWith((ref) {
            throw StateError('Reviewer bypass must not request backend auth');
          }),
          childProfilesProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(container.dispose);
      await container.read(childProfilesProvider.future);
      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SignUpScreen), findsOneWidget);
      final visited = <String>[];
      router.routerDelegate.addListener(() {
        visited.add(router.routerDelegate.currentConfiguration.uri.path);
      });
      await tester.enterText(find.byType(TextField), appReviewBypassEmail);
      final submit = find.text('Create Account with Magic Link');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byType(ReviewOnboardingScreen), findsOneWidget);
      expect(review.state.parentBirthYear, verifiedYear);
      expect(visited, isNot(contains('/parent-birth-year')));
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  for (final signUp in [false, true]) {
    testWidgets(
      '${signUp ? 'signup' : 'signin'} retains mail round trip and OTP draft through failure',
      (tester) async {
        final entry = EntryFlowNotifier();
        await entry.ready;
        entry.beginParentEntry(
          signUp ? EntryAuthIntent.signUp : EntryAuthIntent.signIn,
        );
        entry.authorizeParentAfterPassedGate();
        expect(entry.verifyAdultYear(DateTime.now().year - 30), true);
        final repository = _MailRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entryFlowNotifierProvider.overrideWith((ref) => entry),
              authRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              home: signUp ? const SignUpScreen() : const SignInScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          ' parent@example.com ',
        );
        final send = find.text(
          signUp ? 'Create Account with Magic Link' : 'Email Me a Magic Link',
        );
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(repository.sentEmail, 'parent@example.com');
        expect(repository.createsUser, signUp);
        expect(find.textContaining('Email sent.'), findsOneWidget);
        entry.didChangeAppLifecycleState(AppLifecycleState.paused);
        entry.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(entry.state.isAdultVerified, true);

        final code = find.byType(TextField).last;
        await tester.enterText(code, '123456');
        repository.verifyError = const AppAuthException('Code expired');
        final verify = find.text('Verify Code');
        await tester.ensureVisible(verify);
        await tester.tap(verify);
        await tester.pumpAndSettle();
        expect(find.text('Code expired'), findsOneWidget);
        expect(tester.widget<TextField>(code).controller!.text, '123456');
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          ' parent@example.com ',
        );
        repository.verifyError = null;
        await tester.ensureVisible(verify);
        await tester.tap(verify);
        await tester.pumpAndSettle();
        expect(repository.verifiedCode, '123456');
        // A successful OTP ends the lifecycle exception; the router, not this
        // screen, owns advancing when the backend session arrives.
        expect(
          find.byType(signUp ? SignUpScreen : SignInScreen),
          findsOneWidget,
        );
        entry.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(entry.state.isParentAuthorized, false);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '${signUp ? 'signup' : 'signin'} failed email send ends parent lifecycle exception',
      (tester) async {
        final entry = EntryFlowNotifier();
        await entry.ready;
        entry.beginParentEntry(
          signUp ? EntryAuthIntent.signUp : EntryAuthIntent.signIn,
        );
        entry.authorizeParentAfterPassedGate();
        entry.verifyAdultYear(DateTime.now().year - 30);
        final repository = _MailRepository()
          ..sendError = const AppAuthException('Email unavailable');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              entryFlowNotifierProvider.overrideWith((ref) => entry),
              authRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              home: signUp ? const SignUpScreen() : const SignInScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          'parent@example.com',
        );
        final send = find.text(
          signUp ? 'Create Account with Magic Link' : 'Email Me a Magic Link',
        );
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(find.text('Email unavailable'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        entry.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(entry.state.isParentAuthorized, false);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
