import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/gen_ui/domain/gen_ui_card_schema.dart';

void main() {
  group('GenUiCardSchema validation', () {
    test('accepts whitelisted reader true/false schemas', () {
      final schema = GenUiCardSchema.fromJson({
        'id': 'tf-1',
        'surface': 'reader',
        'type': 'true_false',
        'prompt': 'Did the moon help Luna?',
        'skippable': true,
        'graded': true,
        'choices': [
          {
            'id': 'true',
            'label': 'True',
            'accessibilityLabel': 'True, the moon helped Luna',
            'emoji': '🌙',
            'isCorrect': true,
          },
          {
            'id': 'false',
            'label': 'False',
            'accessibilityLabel': 'False, the moon did not help',
            'emoji': '☁️',
            'isCorrect': false,
          },
        ],
      });

      expect(schema.validation.isValid, isTrue);
      expect(schema.type, GenUiCardType.trueFalse);
      expect(schema.isEmotional, isFalse);
    });

    test('rejects arbitrary card types outside the whitelist', () {
      final schema = GenUiCardSchema.fromJson({
        'id': 'unsafe',
        'surface': 'reader',
        'type': 'freeform_html',
        'prompt': 'Render this',
        'choices': const [],
      });

      expect(schema.validation.isValid, isFalse);
      expect(
        schema.validation.errors,
        contains('Unsupported Gen-UI card type: freeform_html'),
      );
    });

    test(
      'requires visual choices to include label and accessibility label',
      () {
        final schema = GenUiCardSchema.fromJson({
          'id': 'visual-1',
          'surface': 'reader',
          'type': 'picture_choice',
          'prompt': 'Which picture matches the page?',
          'choices': [
            {'id': 'fox', 'emoji': '🦊', 'accessibilityLabel': 'A fox'},
            {'id': 'owl', 'emoji': '🦉', 'label': 'Owl'},
          ],
        });

        expect(schema.validation.isValid, isFalse);
        expect(
          schema.validation.errors,
          contains('Choice fox must include a non-empty label.'),
        );
        expect(
          schema.validation.errors,
          contains('Choice owl must include a non-empty accessibility label.'),
        );
      },
    );

    test('does not allow emotional cards to be graded', () {
      final schema = GenUiCardSchema.fromJson({
        'id': 'feel-1',
        'surface': 'reader',
        'type': 'feeling_check_in',
        'prompt': 'How did this page make you feel?',
        'graded': true,
        'choices': [
          {
            'id': 'brave',
            'label': 'Brave',
            'accessibilityLabel': 'I feel brave',
            'emoji': '🦁',
            'emotionTone': 'positive',
          },
        ],
      });

      expect(schema.isEmotional, isTrue);
      expect(schema.validation.isValid, isFalse);
      expect(
        schema.validation.errors,
        contains('Emotional Gen-UI cards cannot be graded.'),
      );
    });
  });
}
