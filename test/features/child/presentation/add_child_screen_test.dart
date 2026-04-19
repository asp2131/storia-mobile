import 'package:Storia_Kids/src/features/child/domain/child_profile.dart';
import 'package:Storia_Kids/src/features/child/presentation/add_child_screen.dart';
import 'package:Storia_Kids/src/features/child/providers/active_child_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeActiveChildNotifier extends ActiveChildNotifier {
  ChildProfile? createdChild;
  Map<String, dynamic>? lastCreateArgs;

  @override
  Future<ChildProfile?> build() async => null;

  @override
  Future<ChildProfile> createChild(CreateChildProfileInput input) async {
    lastCreateArgs = input.toJson();
    createdChild = ChildProfile(
      id: 'child-1',
      displayName: input.displayName.trim(),
      ageBand: input.ageBand,
      readingLevel: input.readingLevel?.trim().isEmpty == true
          ? null
          : input.readingLevel?.trim(),
      isDefault: input.isDefault,
    );
    return createdChild!;
  }
}

Future<_FakeActiveChildNotifier> _pumpScreen(
  WidgetTester tester, {
  Widget child = const AddChildScreen(),
}) async {
  final notifier = _FakeActiveChildNotifier();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeChildProvider.overrideWith(() => notifier)],
      child: MaterialApp(home: child),
    ),
  );

  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  testWidgets('validates required fields before submit', (tester) async {
    await _pumpScreen(tester);

    await tester.ensureVisible(find.text('Save child profile'));
    await tester.tap(find.text('Save child profile'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a display name.'), findsOneWidget);
    expect(find.text('Choose an age band.'), findsOneWidget);
  });

  testWidgets('submits child profile values', (tester) async {
    final notifier = await _pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField), '  Ava  ');
    await tester.ensureVisible(find.text('7-9'));
    await tester.tap(find.text('7-9'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField).last);
    await tester.enterText(find.byType(TextField).last, ' Early reader ');

    await tester.ensureVisible(find.text('Save child profile'));
    await tester.tap(find.text('Save child profile'));
    await tester.pumpAndSettle();

    expect(notifier.lastCreateArgs, isNotNull);
    expect(notifier.lastCreateArgs!['displayName'], 'Ava');
    expect(notifier.lastCreateArgs!['ageBand'], '7-9');
    expect(notifier.lastCreateArgs!['readingLevel'], 'Early reader');
    expect(notifier.lastCreateArgs!['isDefault'], isTrue);
  });

  testWidgets('pops with success result after saving child profile', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const AddChildScreen(),
                    ),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('result=$result')),
                    );
                  }
                },
                child: const Text('Open add child'),
              ),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('Open add child'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Milo');
    await tester.ensureVisible(find.text('5-6'));
    await tester.tap(find.text('5-6'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save child profile'));
    await tester.tap(find.text('Save child profile'));
    await tester.pumpAndSettle();

    expect(find.text('Add a child profile'), findsNothing);
    expect(find.text('result=true'), findsOneWidget);
  });
}
