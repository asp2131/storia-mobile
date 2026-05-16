import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/gen_ui/domain/gen_ui_activity.dart';
import 'package:storia_kids/src/features/gen_ui/domain/gen_ui_card_schema.dart';
import 'package:storia_kids/src/features/gen_ui/domain/gen_ui_prompt_policy.dart';

void main() {
  group('GenUiPromptPolicy', () {
    test('reduces prompts after repeated skips', () {
      final policy = GenUiPromptPolicy();
      final log = GenUiActivityLog(
        events: [
          GenUiActivityEvent.skip(
            cardId: 'a',
            cardType: GenUiCardType.trueFalse,
          ),
          GenUiActivityEvent.skip(
            cardId: 'b',
            cardType: GenUiCardType.pictureChoice,
          ),
          GenUiActivityEvent.skip(
            cardId: 'c',
            cardType: GenUiCardType.feelingCheckIn,
          ),
        ],
      );

      expect(policy.shouldPrompt(pageIndex: 3, log: log), isFalse);
      expect(policy.shouldPrompt(pageIndex: 4, log: log), isTrue);
    });

    test('prefers the card type the child engages with most often', () {
      final policy = GenUiPromptPolicy();
      final candidates = [_trueFalseCard, _feelingCard];
      final log = GenUiActivityLog(
        events: [
          GenUiActivityEvent.answer(
            cardId: 'feel-old',
            cardType: GenUiCardType.feelingCheckIn,
            choiceId: 'curious',
            emotionTone: GenUiEmotionTone.positive,
          ),
          GenUiActivityEvent.answer(
            cardId: 'feel-new',
            cardType: GenUiCardType.feelingCheckIn,
            choiceId: 'brave',
            emotionTone: GenUiEmotionTone.positive,
          ),
        ],
      );

      expect(policy.chooseCard(candidates: candidates, log: log), _feelingCard);
    });

    test('does not return invalid schemas', () {
      final policy = GenUiPromptPolicy();
      final invalid = GenUiCardSchema.fromJson({
        'id': 'bad',
        'surface': 'reader',
        'type': 'feeling_check_in',
        'prompt': 'How do you feel?',
        'graded': true,
        'choices': [
          {
            'id': 'sad',
            'label': 'Sad',
            'accessibilityLabel': 'I feel sad',
            'emoji': '🌧️',
          },
        ],
      });

      expect(
        policy.chooseCard(candidates: [invalid], log: const GenUiActivityLog()),
        isNull,
      );
    });
  });
}

final _trueFalseCard = GenUiCardSchema.fromJson({
  'id': 'tf',
  'surface': 'reader',
  'type': 'true_false',
  'prompt': 'Did the fox hide?',
  'graded': true,
  'choices': [
    {
      'id': 'yes',
      'label': 'Yes',
      'accessibilityLabel': 'Yes, the fox hid',
      'emoji': '🦊',
      'isCorrect': true,
    },
    {
      'id': 'no',
      'label': 'No',
      'accessibilityLabel': 'No, the fox did not hide',
      'emoji': '🍄',
      'isCorrect': false,
    },
  ],
});

final _feelingCard = GenUiCardSchema.fromJson({
  'id': 'feel',
  'surface': 'reader',
  'type': 'feeling_check_in',
  'prompt': 'How did this page feel?',
  'choices': [
    {
      'id': 'curious',
      'label': 'Curious',
      'accessibilityLabel': 'I feel curious',
      'emoji': '✨',
      'emotionTone': 'positive',
    },
    {
      'id': 'worried',
      'label': 'Worried',
      'accessibilityLabel': 'I feel worried',
      'emoji': '🌧️',
      'emotionTone': 'harder',
    },
  ],
});
