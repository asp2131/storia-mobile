enum GenUiCardType {
  trueFalse('true_false'),
  pictureChoice('picture_choice'),
  characterEmpathy('character_empathy'),
  feelingCheckIn('feeling_check_in'),
  personalConnection('personal_connection'),
  reflectionPrompt('reflection_prompt'),
  wordHunt('word_hunt');

  const GenUiCardType(this.wireName);

  final String wireName;

  static GenUiCardType? fromWireName(String? value) {
    for (final type in values) {
      if (type.wireName == value) return type;
    }
    return null;
  }
}

enum GenUiEmotionTone {
  positive('positive'),
  neutral('neutral'),
  harder('harder');

  const GenUiEmotionTone(this.wireName);

  final String wireName;

  static GenUiEmotionTone? fromWireName(String? value) {
    for (final tone in values) {
      if (tone.wireName == value) return tone;
    }
    return null;
  }
}

class GenUiChoiceSchema {
  const GenUiChoiceSchema({
    required this.id,
    required this.label,
    required this.accessibilityLabel,
    this.emoji,
    this.isCorrect,
    this.emotionTone,
  });

  factory GenUiChoiceSchema.fromJson(Map<String, dynamic> json) {
    return GenUiChoiceSchema(
      id: _string(json['id']),
      label: _string(json['label']),
      accessibilityLabel: _string(json['accessibilityLabel']),
      emoji: _nullableString(json['emoji']),
      isCorrect: json['isCorrect'] as bool?,
      emotionTone: GenUiEmotionTone.fromWireName(
        json['emotionTone'] as String?,
      ),
    );
  }

  final String id;
  final String label;
  final String accessibilityLabel;
  final String? emoji;
  final bool? isCorrect;
  final GenUiEmotionTone? emotionTone;
}

class GenUiCardValidation {
  const GenUiCardValidation({required this.errors});

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

class GenUiCardSchema {
  GenUiCardSchema({
    required this.id,
    required this.surface,
    required this.rawType,
    required this.type,
    required this.prompt,
    required this.supportingText,
    required this.pageIndex,
    required this.skippable,
    required this.graded,
    required this.choices,
  }) : validation = GenUiCardValidation(
         errors: _validate(
           id: id,
           type: type,
           rawType: rawType,
           prompt: prompt,
           graded: graded,
           choices: choices,
         ),
       );

  factory GenUiCardSchema.fromJson(Map<String, dynamic> json) {
    final rawType = _nullableString(json['type']);
    final type = GenUiCardType.fromWireName(rawType);
    final rawChoices = json['choices'];
    return GenUiCardSchema(
      id: _string(json['id']),
      surface: _nullableString(json['surface']) ?? 'reader',
      rawType: rawType ?? '',
      type: type,
      prompt: _string(json['prompt']),
      supportingText: _nullableString(json['supportingText']),
      pageIndex: _int(json['pageIndex'] ?? json['page_index']),
      skippable: json['skippable'] as bool? ?? true,
      graded: json['graded'] as bool? ?? false,
      choices: rawChoices is List
          ? rawChoices
                .whereType<Map<String, dynamic>>()
                .map(GenUiChoiceSchema.fromJson)
                .toList(growable: false)
          : const <GenUiChoiceSchema>[],
    );
  }

  final String id;
  final String surface;
  final String rawType;
  final GenUiCardType? type;
  final String prompt;
  final String? supportingText;
  final int pageIndex;
  final bool skippable;
  final bool graded;
  final List<GenUiChoiceSchema> choices;
  final GenUiCardValidation validation;

  bool get isEmotional {
    return type == GenUiCardType.characterEmpathy ||
        type == GenUiCardType.feelingCheckIn ||
        type == GenUiCardType.personalConnection;
  }

  static List<String> _validate({
    required String id,
    required GenUiCardType? type,
    required String rawType,
    required String prompt,
    required bool graded,
    required List<GenUiChoiceSchema> choices,
  }) {
    final errors = <String>[];
    if (id.trim().isEmpty) errors.add('Gen-UI card must include an id.');
    if (type == null) {
      errors.add('Unsupported Gen-UI card type: $rawType');
    }
    if (prompt.trim().isEmpty) {
      errors.add('Gen-UI card must include a prompt.');
    }
    if (choices.isEmpty) {
      errors.add('Gen-UI card must include at least one choice.');
    }
    for (final choice in choices) {
      final choiceId = choice.id.isEmpty ? '(missing id)' : choice.id;
      if (choice.label.trim().isEmpty) {
        errors.add('Choice $choiceId must include a non-empty label.');
      }
      if (choice.accessibilityLabel.trim().isEmpty) {
        errors.add(
          'Choice $choiceId must include a non-empty accessibility label.',
        );
      }
    }
    if ((type == GenUiCardType.characterEmpathy ||
            type == GenUiCardType.feelingCheckIn ||
            type == GenUiCardType.personalConnection) &&
        graded) {
      errors.add('Emotional Gen-UI cards cannot be graded.');
    }
    return errors;
  }
}

String _string(Object? value) => value is String ? value.trim() : '';
String? _nullableString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _int(Object? value) {
  if (value is num && value.isFinite) return value.toInt();
  return 0;
}
