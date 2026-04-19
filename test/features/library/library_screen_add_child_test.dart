import 'package:Storia_Kids/src/data/models.dart';
import 'package:Storia_Kids/src/data/providers.dart';
import 'package:Storia_Kids/src/features/child/domain/child_profile.dart';
import 'package:Storia_Kids/src/features/child/presentation/add_child_screen.dart';
import 'package:Storia_Kids/src/features/child/providers/active_child_provider.dart';
import 'package:Storia_Kids/src/features/library/library_screen.dart';
import 'package:Storia_Kids/src/features/progress/providers/progress_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeActiveChildNotifier extends ActiveChildNotifier {
  @override
  Future<ChildProfile?> build() async => null;
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/library',
    routes: [
      GoRoute(
        path: '/library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/children/new',
        builder: (context, state) => const AddChildScreen(),
      ),
    ],
  );
}

void main() {
  testWidgets('shows add child CTA and navigates to add child form', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeChildProvider.overrideWith(_FakeActiveChildNotifier.new),
          childProfilesProvider.overrideWith((ref) async => const []),
          bookLibraryProvider.overrideWith((ref) async => const <Book>[]),
          continueReadingProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp.router(routerConfig: _router()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Add child'), findsOneWidget);
    expect(find.text('Choose child'), findsNothing);

    await tester.ensureVisible(find.text('Add child'));
    await tester.tap(find.text('Add child'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Add a child profile'), findsOneWidget);
    expect(find.text('Save child profile'), findsOneWidget);
  });
}
