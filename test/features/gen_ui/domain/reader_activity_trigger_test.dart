import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/gen_ui/domain/gen_ui_card_schema.dart';
import 'package:storia_kids/src/features/gen_ui/domain/reader_activity_trigger.dart';

GenUiCardSchema _card({int? anchor}) => GenUiCardSchema.fromJson({
      'id': 'c-1',
      'surface': 'reader',
      'type': 'picture_choice',
      'prompt': 'Which one?',
      if (anchor != null) 'anchor_word_index': anchor,
      'choices': [
        {'id': 'x', 'label': 'X', 'accessibilityLabel': 'X', 'emoji': '🦋'},
      ],
    });

void main() {
  group('isActivityLive', () {
    test('null card is never live', () {
      expect(
        isActivityLive(
          card: null,
          isNarrationPlaying: true,
          activeNarratedWordIndex: 99,
        ),
        isFalse,
      );
    });

    test('null anchor is live immediately', () {
      expect(
        isActivityLive(
          card: _card(anchor: null),
          isNarrationPlaying: true,
          activeNarratedWordIndex: -1,
        ),
        isTrue,
      );
    });

    test('narration off (self-read MVP) is live on load regardless of anchor', () {
      expect(
        isActivityLive(
          card: _card(anchor: 10),
          isNarrationPlaying: false,
          activeNarratedWordIndex: -1,
        ),
        isTrue,
      );
    });

    test('read-aloud not live until narrated word reaches anchor', () {
      expect(
        isActivityLive(
          card: _card(anchor: 10),
          isNarrationPlaying: true,
          activeNarratedWordIndex: 9,
        ),
        isFalse,
      );
    });

    test('read-aloud live once narrated word reaches anchor', () {
      expect(
        isActivityLive(
          card: _card(anchor: 10),
          isNarrationPlaying: true,
          activeNarratedWordIndex: 10,
        ),
        isTrue,
      );
    });
  });
}
