import 'gen_ui_card_schema.dart';

enum GenUiActivityAction { answered, skipped }

class GenUiActivityEvent {
  GenUiActivityEvent._({
    required this.cardId,
    required this.cardType,
    required this.action,
    this.choiceId,
    this.wasCorrect,
    this.emotionTone,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();

  factory GenUiActivityEvent.answer({
    required String cardId,
    required GenUiCardType cardType,
    required String choiceId,
    bool? wasCorrect,
    GenUiEmotionTone? emotionTone,
    DateTime? occurredAt,
  }) {
    return GenUiActivityEvent._(
      cardId: cardId,
      cardType: cardType,
      action: GenUiActivityAction.answered,
      choiceId: choiceId,
      wasCorrect: wasCorrect,
      emotionTone: emotionTone,
      occurredAt: occurredAt,
    );
  }

  factory GenUiActivityEvent.skip({
    required String cardId,
    required GenUiCardType cardType,
    DateTime? occurredAt,
  }) {
    return GenUiActivityEvent._(
      cardId: cardId,
      cardType: cardType,
      action: GenUiActivityAction.skipped,
      occurredAt: occurredAt,
    );
  }

  final String cardId;
  final GenUiCardType cardType;
  final GenUiActivityAction action;
  final String? choiceId;
  final bool? wasCorrect;
  final GenUiEmotionTone? emotionTone;
  final DateTime occurredAt;
}

class GenUiActivityLog {
  const GenUiActivityLog({this.events = const []});

  final List<GenUiActivityEvent> events;

  GenUiActivityLog add(GenUiActivityEvent event) {
    return GenUiActivityLog(events: [...events, event]);
  }

  bool hasInteractedWith(String cardId) {
    return events.any((event) => event.cardId == cardId);
  }

  int get consecutiveSkips {
    var count = 0;
    for (final event in events.reversed) {
      if (event.action != GenUiActivityAction.skipped) break;
      count++;
    }
    return count;
  }

  Iterable<GenUiActivityEvent> get answers =>
      events.where((event) => event.action == GenUiActivityAction.answered);

  Iterable<GenUiActivityEvent> get skips =>
      events.where((event) => event.action == GenUiActivityAction.skipped);

  int get answeredCount => answers.length;

  int get skippedCount => skips.length;

  int get harderEmotionCount => answers
      .where((event) => event.emotionTone == GenUiEmotionTone.harder)
      .length;

  int get positiveOrNeutralEmotionCount => answers
      .where(
        (event) =>
            event.emotionTone == GenUiEmotionTone.positive ||
            event.emotionTone == GenUiEmotionTone.neutral,
      )
      .length;

  Map<GenUiCardType, int> get answeredCountsByType {
    final counts = <GenUiCardType, int>{};
    for (final event in answers) {
      counts[event.cardType] = (counts[event.cardType] ?? 0) + 1;
    }
    return counts;
  }

  Map<GenUiCardType, int> get answeredCountByType => answeredCountsByType;
}
