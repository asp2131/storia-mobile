import 'package:flutter/foundation.dart';

@immutable
class PronunciationHighlightPart {
  const PronunciationHighlightPart({
    required this.text,
    this.startMs,
    this.endMs,
  });

  final String text;
  final int? startMs;
  final int? endMs;

  bool get hasTiming => startMs != null && endMs != null && endMs! > startMs!;
}
