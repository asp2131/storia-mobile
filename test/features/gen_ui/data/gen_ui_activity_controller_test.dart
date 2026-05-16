import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/gen_ui/data/gen_ui_activity_controller.dart';
import 'package:storia_kids/src/features/gen_ui/domain/gen_ui_activity.dart';
import 'package:storia_kids/src/features/gen_ui/domain/gen_ui_card_schema.dart';

void main() {
  group('GenUiActivityController', () {
    test('records skips neutrally without correctness', () {
      final controller = GenUiActivityController();

      controller.skip(_feelingCard);

      final event = controller.state.events.single;
      expect(event.action, GenUiActivityAction.skipped);
      expect(event.wasCorrect, isNull);
      expect(controller.state.hasInteractedWith(_feelingCard.id), isTrue);
    });

    test('records graded comprehension answers with correctness', () {
      final controller = GenUiActivityController();

      controller.answer(_trueFalseCard, _trueFalseCard.choices.first);

      final event = controller.state.events.single;
      expect(event.action, GenUiActivityAction.answered);
      expect(event.wasCorrect, isTrue);
    });

    test(
      'records emotional answers without grading even if a choice has correctness metadata',
      () {
        final controller = GenUiActivityController();

        controller.answer(_feelingCard, _feelingCard.choices.first);

        final event = controller.state.events.single;
        expect(event.action, GenUiActivityAction.answered);
        expect(event.wasCorrect, isNull);
        expect(event.emotionTone, GenUiEmotionTone.harder);
      },
    );
  });
}

final _trueFalseCard = GenUiCardSchema.fromJson({
  'id': 'tf',
  'surface': 'reader',
  'type': 'true_false',
  'prompt': 'Did the lantern glow?',
  'graded': true,
  'choices': [
    {
      'id': 'true',
      'label': 'True',
      'accessibilityLabel': 'True, the lantern glowed',
      'emoji': '🏮',
      'isCorrect': true,
    },
    {
      'id': 'false',
      'label': 'False',
      'accessibilityLabel': 'False, the lantern stayed dark',
      'emoji': '🌑',
      'isCorrect': false,
    },
  ],
});

final _feelingCard = GenUiCardSchema.fromJson({
  'id': 'feel',
  'surface': 'reader',
  'type': 'feeling_check_in',
  'prompt': 'How did the shadow page feel?',
  'choices': [
    {
      'id': 'worried',
      'label': 'Worried',
      'accessibilityLabel': 'I feel worried',
      'emoji': '🌧️',
      'isCorrect': true,
      'emotionTone': 'harder',
    },
  ],
});
