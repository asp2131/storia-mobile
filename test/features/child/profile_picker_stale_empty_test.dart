import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/child/data/child_profile_providers.dart';
import 'package:loratone/src/features/child/domain/child_profile.dart';
import 'package:loratone/src/features/child/presentation/add_child_screen.dart';
import 'package:loratone/src/features/child/presentation/profile_picker_screen.dart';

final _signedIn = StateProvider<bool>((ref) => false);

void main() {
  testWidgets(
    'stale signed-out [] does not flash onboarding while real profiles load',
    (tester) async {
      final pending = Completer<List<ChildProfile>>();
      final container = ProviderContainer(
        overrides: [
          childProfilesProvider.overrideWith((ref) {
            if (!ref.watch(_signedIn)) return const <ChildProfile>[];
            return pending.future;
          }),
          activeChildProfileIdStateProvider.overrideWith(
            (ref) => ActiveChildProfileIdNotifier(userId: null),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Signed out: provider settles on [].
      expect(await container.read(childProfilesProvider.future), isEmpty);
      // Sign in: provider reloads, still carrying [] as its previous value.
      container.read(_signedIn.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ProfilePickerScreen()),
        ),
      );

      expect(find.byType(AddChildScreen), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(const [
        ChildProfile(
          id: 'child-a',
          userId: 'parent',
          displayName: 'Reader A',
          ageBand: '7-9',
          isDefault: true,
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.byType(AddChildScreen), findsNothing);
      expect(find.text('Reader A'), findsOneWidget);
    },
  );
}
