import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gen_ui_activity.dart';
import '../domain/gen_ui_card_schema.dart';

class GenUiActivityController extends StateNotifier<GenUiActivityLog> {
  GenUiActivityController([GenUiActivityLog? initialLog])
    : super(initialLog ?? const GenUiActivityLog());

  void answer(GenUiCardSchema card, GenUiChoiceSchema choice) {
    final cardType = card.type;
    if (cardType == null || !card.validation.isValid) return;

    state = state.add(
      GenUiActivityEvent.answer(
        cardId: card.id,
        cardType: cardType,
        choiceId: choice.id,
        wasCorrect: card.isEmotional || !card.graded ? null : choice.isCorrect,
        emotionTone: choice.emotionTone,
      ),
    );
  }

  void skip(GenUiCardSchema card) {
    final cardType = card.type;
    if (cardType == null || !card.validation.isValid) return;
    state = state.add(
      GenUiActivityEvent.skip(cardId: card.id, cardType: cardType),
    );
  }
}
