import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/onboarding/data/entry_flow_provider.dart';
import 'package:loratone/src/features/onboarding/domain/entry_flow_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;
  late EntryFlowNotifier notifier;

  setUp(() {
    now = DateTime.utc(2034, 10, 5, 12);
    notifier = EntryFlowNotifier(clock: () => now);
  });

  tearDown(() {
    notifier.dispose();
  });

  Future<void> enterAdultParent({bool saveSample = true}) async {
    await notifier.ready;
    notifier.beginParentEntry(EntryAuthIntent.signUp, saveSample: saveSample);
    expect(notifier.authorizeParentAfterPassedGate(), isTrue);
    expect(notifier.verifyAdultYear(2016), isTrue);
  }

  group('Parent authorization', () {
    test(
      'starting parent entry records a typed return without granting access',
      () async {
        await notifier.ready;

        notifier.beginParentEntry(EntryAuthIntent.signIn, saveSample: true);

        expect(notifier.state.isReady, isTrue);
        expect(notifier.state.pendingAuthIntent, EntryAuthIntent.signIn);
        expect(
          notifier.state.pendingSampleSave,
          SampleSaveDestination.sampleReader,
        );
        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
        expect(notifier.verifyAdultYear(1980), isFalse);
        expect(notifier.beginAuthRoundTrip(), isFalse);
      },
    );

    test(
      'grant requires ready state and an explicitly requested parent entry',
      () async {
        expect(notifier.authorizeParentAfterPassedGate(), isFalse);
        await notifier.ready;
        expect(notifier.authorizeParentAfterPassedGate(), isFalse);

        notifier.beginParentEntry(EntryAuthIntent.signIn);
        expect(notifier.authorizeParentAfterPassedGate(), isTrue);
        expect(notifier.state.isParentAuthorized, isTrue);
        expect(notifier.state.isAdultVerified, isFalse);
        expect(notifier.beginAuthRoundTrip(), isFalse);
      },
    );

    test(
      'birth-year validation uses injected year and clears invalid verification',
      () async {
        await notifier.ready;
        notifier.beginParentEntry(EntryAuthIntent.signIn);
        notifier.authorizeParentAfterPassedGate();

        for (final year in <int>[0, 1929, 2017, 2035]) {
          expect(notifier.verifyAdultYear(year), isFalse, reason: '$year');
          expect(notifier.state.isAdultVerified, isFalse);
        }
        expect(notifier.verifyAdultYear(2016), isTrue);
        expect(notifier.state.isAdultVerified, isTrue);
        expect(notifier.verifiedParentBirthYearForReview(), 2016);
        expect(notifier.verifyAdultYear(2017), isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
        expect(notifier.verifiedParentBirthYearForReview(), isNull);
      },
    );

    test(
      'gate access expires exactly at ten minutes, not one microsecond early',
      () async {
        await enterAdultParent();
        now = now
            .add(const Duration(minutes: 10))
            .subtract(const Duration(microseconds: 1));
        expect(notifier.state.isParentAuthorized, isTrue);
        expect(notifier.state.isAdultVerified, isTrue);

        now = now.add(const Duration(microseconds: 1));
        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
        expect(notifier.verifiedParentBirthYearForReview(), isNull);
        expect(notifier.verifyAdultYear(1980), isFalse);
        expect(
          notifier.state.pendingSampleSave,
          SampleSaveDestination.sampleReader,
        );
      },
    );

    test(
      'auth and repeated gate callbacks cannot extend an active deadline',
      () async {
        await enterAdultParent();
        now = now.add(const Duration(minutes: 9));
        expect(notifier.authorizeParentAfterPassedGate(), isTrue);
        expect(notifier.beginAuthRoundTrip(), isTrue);
        notifier.endAuthRoundTrip();
        expect(notifier.state.isParentAuthorized, isTrue);

        now = now.add(const Duration(minutes: 1));
        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
      },
    );

    test(
      'a new gate after expiration grants a new window, not adult verification',
      () async {
        await enterAdultParent();
        now = now.add(const Duration(minutes: 10));
        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.authorizeParentAfterPassedGate(), isTrue);
        expect(notifier.state.isParentAuthorized, isTrue);
        expect(notifier.state.isAdultVerified, isFalse);
        expect(
          notifier.state.pendingSampleSave,
          SampleSaveDestination.sampleReader,
        );
      },
    );

    test(
      'snapshots remain immutable when authorization later changes',
      () async {
        await enterAdultParent();
        final authorized = notifier.state;
        notifier.invalidateParentAccess();

        expect(authorized.isParentAuthorized, isTrue);
        expect(authorized.isAdultVerified, isTrue);
        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
      },
    );
  });

  group('Relock and typed sample return', () {
    test(
      'ordinary background relocks without losing the sample return',
      () async {
        await enterAdultParent();
        notifier.didChangeAppLifecycleState(AppLifecycleState.inactive);
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
        expect(notifier.state.pendingAuthIntent, EntryAuthIntent.signUp);
        expect(
          notifier.state.pendingSampleSave,
          SampleSaveDestination.sampleReader,
        );
        notifier.endAuthRoundTrip();
        expect(notifier.state.isParentAuthorized, isFalse);
      },
    );

    test(
      'late gate completion cannot authorize while app is backgrounded',
      () async {
        await notifier.ready;
        notifier.beginParentEntry(EntryAuthIntent.signIn, saveSample: true);
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);

        expect(notifier.authorizeParentAfterPassedGate(), isFalse);
        expect(notifier.verifyAdultYear(1980), isFalse);
        expect(notifier.beginAuthRoundTrip(), isFalse);
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(notifier.state.isParentAuthorized, isFalse);
        expect(
          notifier.state.pendingSampleSave,
          SampleSaveDestination.sampleReader,
        );
      },
    );

    test(
      'only explicitly started auth can retain live access during background',
      () async {
        await enterAdultParent();
        expect(notifier.beginAuthRoundTrip(), isTrue);
        notifier.didChangeAppLifecycleState(AppLifecycleState.inactive);
        notifier.didChangeAppLifecycleState(AppLifecycleState.hidden);
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 9));
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
        notifier.endAuthRoundTrip();

        expect(notifier.state.isParentAuthorized, isTrue);
        expect(notifier.state.isAdultVerified, isTrue);
        expect(notifier.state.pendingAuthIntent, EntryAuthIntent.signUp);
        expect(
          notifier.state.pendingSampleSave,
          SampleSaveDestination.sampleReader,
        );

        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(notifier.state.isParentAuthorized, isFalse);
      },
    );

    test(
      'auth callback after its original deadline cannot restore access',
      () async {
        await enterAdultParent();
        expect(notifier.beginAuthRoundTrip(), isTrue);
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 10));
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
        notifier.endAuthRoundTrip();

        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
        expect(notifier.verifiedParentBirthYearForReview(), isNull);
        expect(
          notifier.state.pendingSampleSave,
          SampleSaveDestination.sampleReader,
        );
      },
    );

    test(
      'cancelling auth relocks and preserves the unclaimed sample return',
      () async {
        await enterAdultParent();
        notifier.beginAuthRoundTrip();
        notifier.endAuthRoundTrip(cancelled: true);

        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
        expect(notifier.state.pendingAuthIntent, isNull);
        expect(
          notifier.state.pendingSampleSave,
          SampleSaveDestination.sampleReader,
        );
        notifier.beginParentEntry(EntryAuthIntent.signIn);
        expect(
          notifier.state.pendingSampleSave,
          SampleSaveDestination.sampleReader,
        );
      },
    );

    test(
      'invalidating access cannot be undone by a late successful callback',
      () async {
        await enterAdultParent();
        notifier.beginAuthRoundTrip();
        notifier.invalidateParentAccess();
        notifier.endAuthRoundTrip();

        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
        expect(
          notifier.state.pendingSampleSave,
          SampleSaveDestination.sampleReader,
        );
      },
    );

    test(
      'sign-out clears all entry intents and no callback can revive them',
      () async {
        await enterAdultParent();
        notifier.beginAuthRoundTrip();
        notifier.invalidateParentAccess(clearPendingIntent: true);
        notifier.endAuthRoundTrip();

        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
        expect(notifier.state.pendingAuthIntent, isNull);
        expect(notifier.state.pendingSampleSave, isNull);
      },
    );

    test(
      'detachment always relocks even while an auth round trip is pending',
      () async {
        await enterAdultParent();
        notifier.beginAuthRoundTrip();
        notifier.didChangeAppLifecycleState(AppLifecycleState.detached);
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
        notifier.endAuthRoundTrip();

        expect(notifier.state.isParentAuthorized, isFalse);
        expect(notifier.state.isAdultVerified, isFalse);
      },
    );

    test(
      'a fresh notifier cannot inherit authorization or a pending callback',
      () async {
        await enterAdultParent();
        notifier.beginAuthRoundTrip();
        final fresh = EntryFlowNotifier(clock: () => now);
        addTearDown(fresh.dispose);
        await fresh.ready;
        fresh.endAuthRoundTrip();

        expect(fresh.state.isParentAuthorized, isFalse);
        expect(fresh.state.isAdultVerified, isFalse);
        expect(fresh.state.pendingAuthIntent, isNull);
        expect(fresh.state.pendingSampleSave, isNull);
      },
    );

    test('only confirmed claim clears the typed sample return', () async {
      await enterAdultParent();
      notifier.endAuthRoundTrip();
      expect(
        notifier.state.pendingSampleSave,
        SampleSaveDestination.sampleReader,
      );

      notifier.clearPendingSave();

      expect(notifier.state.pendingSampleSave, isNull);
      expect(notifier.state.isParentAuthorized, isTrue);
      expect(notifier.state.isAdultVerified, isTrue);
    });
  });

  group('Hydration and provider ownership', () {
    test('pending hydration cannot grant or record protected state', () async {
      final hydration = Completer<void>();
      final pending = EntryFlowNotifier(
        clock: () => now,
        hydration: hydration.future,
      );
      addTearDown(pending.dispose);
      pending.beginParentEntry(EntryAuthIntent.signIn, saveSample: true);
      expect(pending.authorizeParentAfterPassedGate(), isFalse);
      expect(pending.verifyAdultYear(1980), isFalse);
      expect(pending.state.isReady, isFalse);
      expect(pending.state.pendingAuthIntent, isNull);

      hydration.complete();
      await pending.ready;
      expect(pending.state.isReady, isTrue);
      expect(pending.state.isParentAuthorized, isFalse);
      expect(pending.state.isAdultVerified, isFalse);
    });

    test('hydration completion after disposal cannot publish state', () async {
      final hydration = Completer<void>();
      final pending = EntryFlowNotifier(hydration: hydration.future);
      var notifications = 0;
      pending.addListener(() => notifications++);
      pending.dispose();
      hydration.complete();
      await pending.ready;

      expect(notifications, 0);
      expect(pending.state.isReady, isFalse);
      expect(pending.authorizeParentAfterPassedGate(), isFalse);
      expect(pending.verifyAdultYear(1980), isFalse);
      expect(pending.beginAuthRoundTrip(), isFalse);
      pending.beginParentEntry(EntryAuthIntent.signIn, saveSample: true);
      pending.endAuthRoundTrip();
      pending.invalidateParentAccess();
      pending.clearPendingSave();
      expect(notifications, 0);
    });

    test(
      'snapshot and router refresh share an offline-safe notifier',
      () async {
        final container = ProviderContainer();
        var snapshots = 0;
        final subscription = container.listen<EntryFlowState>(
          entryFlowProvider,
          (_, _) => snapshots++,
        );
        final source = container.read(entryFlowNotifierProvider);
        var routerRefreshes = 0;
        source.addListener(() => routerRefreshes++);
        await source.ready;

        source.beginParentEntry(EntryAuthIntent.signIn, saveSample: true);
        source.authorizeParentAfterPassedGate();
        source.verifyAdultYear(1980);

        expect(container.read(entryFlowProvider).isParentAuthorized, isTrue);
        expect(container.read(entryFlowProvider).isAdultVerified, isTrue);
        expect(snapshots, greaterThan(0));
        expect(routerRefreshes, greaterThan(0));
        subscription.close();
        expect(container.dispose, returnsNormally);
        expect(source.authorizeParentAfterPassedGate(), isFalse);
      },
    );

    testWidgets('deadline timer refreshes a router without another action', (
      tester,
    ) async {
      notifier.dispose();
      notifier = EntryFlowNotifier(clock: () => now);
      await tester.pump();
      await enterAdultParent();
      var routerRefreshes = 0;
      notifier.addListener(() => routerRefreshes++);
      now = now.add(const Duration(minutes: 10));

      await tester.pump(const Duration(minutes: 10));

      expect(routerRefreshes, 1);
      expect(notifier.state.isParentAuthorized, isFalse);
      expect(notifier.state.isAdultVerified, isFalse);
    });

    test('expiration notification queued before disposal is guarded', () async {
      await enterAdultParent();
      var notifications = 0;
      notifier.addListener(() => notifications++);
      now = now.add(const Duration(minutes: 10));
      expect(notifier.state.isParentAuthorized, isFalse);
      notifier.dispose();
      await Future<void>.value();

      expect(notifications, 0);
    });
  });
}
