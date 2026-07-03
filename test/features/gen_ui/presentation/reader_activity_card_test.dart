import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/gen_ui/domain/gen_ui_card_schema.dart';
import 'package:loratone/src/features/gen_ui/presentation/reader_activity_card.dart';

GenUiCardSchema _pictureCard() => GenUiCardSchema.fromJson({
      'id': 'pic-1',
      'surface': 'reader',
      'type': 'picture_choice',
      'prompt': 'Which picture best matches what happened?',
      'choices': [
        {'id': 'lantern', 'label': 'Lantern', 'accessibilityLabel': 'A lantern', 'emoji': '🏮'},
        {'id': 'rain', 'label': 'Rain', 'accessibilityLabel': 'Rain', 'emoji': '🌧️'},
        {'id': 'fly', 'label': 'Butterfly', 'accessibilityLabel': 'Butterfly', 'emoji': '🦋'},
      ],
    });

GenUiCardSchema _reflectionCard() => GenUiCardSchema.fromJson({
      'id': 'ref-1',
      'surface': 'reader',
      'type': 'reflection_prompt',
      'prompt': 'What is one tiny detail you notice on this page right now?',
      'choices': [
        {
          'id': 'noticed',
          'label': 'I noticed something interesting happening',
          'accessibilityLabel': 'I noticed something',
        },
        {
          'id': 'wonder',
          'label': 'I wonder why that happened the way it did',
          'accessibilityLabel': 'I wonder why',
        },
      ],
    });

Future<void> _pump(WidgetTester tester, GenUiCardSchema card,
    {void Function(GenUiChoiceSchema)? onChoice, VoidCallback? onSkip}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReaderActivityCard(
          card: card,
          onChoiceSelected: onChoice ?? (_) {},
          onSkip: onSkip ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('short emoji choices render as a tile grid', (tester) async {
    await _pump(tester, _pictureCard());
    expect(find.byType(ReaderActivityCard), findsOneWidget);
    expect(find.text('Lantern'), findsOneWidget);
    expect(find.text('Rain'), findsOneWidget);
    expect(find.text('Butterfly'), findsOneWidget);
    // Tile-grid layout uses a Wrap-of-tiles tagged by key.
    expect(find.byKey(const ValueKey('activity-answers-tiles')), findsOneWidget);
    // 3 choices (odd) -> the final tile spans the full row.
    expect(find.byKey(const ValueKey('activity-tile-wide')), findsOneWidget);
  });

  testWidgets('long labels render as stacked rows', (tester) async {
    await _pump(tester, _reflectionCard());
    expect(find.byKey(const ValueKey('activity-answers-stacked')), findsOneWidget);
    expect(find.textContaining('I noticed something'), findsOneWidget);
  });

  testWidgets('tapping a choice invokes onChoiceSelected', (tester) async {
    GenUiChoiceSchema? picked;
    await _pump(tester, _pictureCard(), onChoice: (c) => picked = c);
    await tester.tap(find.text('Lantern'));
    await tester.pump();
    expect(picked?.id, 'lantern');
  });

  testWidgets('tapping the skip button invokes onSkip', (tester) async {
    var skipped = false;
    await _pump(tester, _pictureCard(), onSkip: () => skipped = true);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(skipped, isTrue);
  });
}
