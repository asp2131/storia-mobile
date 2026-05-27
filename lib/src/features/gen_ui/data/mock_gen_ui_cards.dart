import '../domain/gen_ui_card_schema.dart';

class MockGenUiCardRepository {
  const MockGenUiCardRepository();

  List<GenUiCardSchema> readerCardsForPage({
    required String bookId,
    required int pageIndex,
  }) {
    final schemas = _readerCards
        .where((schema) => schema['page_index'] == pageIndex)
        .toList(growable: false);
    return schemas.map(GenUiCardSchema.fromJson).toList(growable: false);
  }
}

const _readerCards = <Map<String, dynamic>>[
  {
    'id': 'unsupported-page-0-demo',
    'surface': 'reader',
    'type': 'freeform_html',
    'page_index': 0,
    'prompt': 'This unsupported schema should be filtered out.',
    'choices': [],
  },
  {
    'id': 'page-0-reflection',
    'surface': 'reader',
    'type': 'reflection_prompt',
    'page_index': 0,
    'prompt': 'What is one tiny detail you notice?',
    'supportingText': 'No right answer—just pause and wonder.',
    'skippable': true,
    'graded': false,
    'choices': [
      {
        'id': 'noticed',
        'label': 'I noticed something',
        'accessibilityLabel': 'I noticed something on the page',
        'emoji': '✨',
      },
      {
        'id': 'wonder',
        'label': 'I wonder why',
        'accessibilityLabel': 'I wonder why something happened',
        'emoji': '💭',
      },
    ],
  },
  {
    'id': 'page-1-truth',
    'surface': 'reader',
    'type': 'true_false',
    'page_index': 1,
    'prompt': 'Did someone try to help on this page?',
    'supportingText': 'Tap the picture that feels right.',
    'skippable': true,
    'graded': true,
    'choices': [
      {
        'id': 'true',
        'label': 'True',
        'accessibilityLabel': 'True, someone tried to help',
        'emoji': '🤝',
        'isCorrect': true,
      },
      {
        'id': 'false',
        'label': 'False',
        'accessibilityLabel': 'False, nobody tried to help',
        'emoji': '🌫️',
        'isCorrect': false,
      },
    ],
  },
  {
    'id': 'page-2-picture',
    'surface': 'reader',
    'type': 'picture_choice',
    'page_index': 2,
    'anchor_word_index': 6,
    'prompt': 'Which picture best matches what happened?',
    'skippable': true,
    'graded': true,
    'choices': [
      {
        'id': 'lantern',
        'label': 'Glowing lantern',
        'accessibilityLabel': 'A glowing lantern',
        'emoji': '🏮',
        'isCorrect': true,
      },
      {
        'id': 'raincloud',
        'label': 'Rain cloud',
        'accessibilityLabel': 'A gray rain cloud',
        'emoji': '🌧️',
        'isCorrect': false,
      },
      {
        'id': 'butterfly',
        'label': 'Butterfly',
        'accessibilityLabel': 'A butterfly',
        'emoji': '🦋',
        'isCorrect': false,
      },
    ],
  },
  {
    'id': 'page-3-empathy',
    'surface': 'reader',
    'type': 'character_empathy',
    'page_index': 3,
    'anchor_word_index': 4,
    'prompt': 'How might the character feel right now?',
    'supportingText': 'There is no wrong answer.',
    'skippable': true,
    'graded': false,
    'choices': [
      {
        'id': 'brave',
        'label': 'Brave',
        'accessibilityLabel': 'The character might feel brave',
        'emoji': '🦁',
        'emotionTone': 'positive',
      },
      {
        'id': 'worried',
        'label': 'Worried',
        'accessibilityLabel': 'The character might feel worried',
        'emoji': '🌧️',
        'emotionTone': 'harder',
      },
      {
        'id': 'curious',
        'label': 'Curious',
        'accessibilityLabel': 'The character might feel curious',
        'emoji': '✨',
        'emotionTone': 'neutral',
      },
    ],
  },
  {
    'id': 'page-4-feeling',
    'surface': 'reader',
    'type': 'feeling_check_in',
    'page_index': 4,
    'prompt': 'How did this page make you feel?',
    'supportingText': 'Pick a feeling, or skip for now.',
    'skippable': true,
    'graded': false,
    'choices': [
      {
        'id': 'happy',
        'label': 'Happy',
        'accessibilityLabel': 'I feel happy',
        'emoji': '😊',
        'emotionTone': 'positive',
      },
      {
        'id': 'quiet',
        'label': 'Quiet',
        'accessibilityLabel': 'I feel quiet',
        'emoji': '🌙',
        'emotionTone': 'neutral',
      },
      {
        'id': 'nervous',
        'label': 'Nervous',
        'accessibilityLabel': 'I feel nervous',
        'emoji': '🫧',
        'emotionTone': 'harder',
      },
    ],
  },
  {
    'id': 'page-5-connection',
    'surface': 'reader',
    'type': 'personal_connection',
    'page_index': 5,
    'prompt': 'Have you ever helped someone like that?',
    'supportingText': 'You can answer with a picture.',
    'skippable': true,
    'graded': false,
    'choices': [
      {
        'id': 'yes-helped',
        'label': 'I have helped',
        'accessibilityLabel': 'Yes, I have helped someone',
        'emoji': '🤲',
        'emotionTone': 'positive',
      },
      {
        'id': 'not-yet',
        'label': 'Not yet',
        'accessibilityLabel': 'Not yet',
        'emoji': '🌱',
        'emotionTone': 'neutral',
      },
    ],
  },
];
