import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/gen_ui/domain/gen_ui_activity.dart';
import 'package:loratone/src/features/gen_ui/domain/gen_ui_card_schema.dart';
import 'package:loratone/src/features/gen_ui/presentation/parent_insight_cards.dart';

void main() {
  testWidgets('renders supportive aggregate parent insights', (tester) async {
    final log = GenUiActivityLog(
      events: [
        GenUiActivityEvent.answer(
          cardId: 'feel-1',
          cardType: GenUiCardType.feelingCheckIn,
          choiceId: 'worried',
          emotionTone: GenUiEmotionTone.harder,
        ),
        GenUiActivityEvent.answer(
          cardId: 'tf-1',
          cardType: GenUiCardType.trueFalse,
          choiceId: 'yes',
          wasCorrect: true,
        ),
        GenUiActivityEvent.skip(
          cardId: 'connection-1',
          cardType: GenUiCardType.personalConnection,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ParentInsightCards(log: log, profileName: 'Maya'),
        ),
      ),
    );

    expect(find.text('Maya’s reading reflections'), findsOneWidget);
    expect(find.textContaining('shared 2 reflections'), findsOneWidget);
    expect(find.textContaining('noticed some bigger feelings'), findsOneWidget);
    expect(find.textContaining('No diagnosis'), findsOneWidget);
  });
}
