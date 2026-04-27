enum PronunciationAudioRole { fullWord, breakdown, unknown }

PronunciationAudioRole inferPronunciationAudioRole(String? url) {
  if (url == null || url.isEmpty) {
    return PronunciationAudioRole.unknown;
  }

  var value = url.toLowerCase();
  try {
    value = Uri.decodeComponent(value);
  } catch (_) {
    // Keep the original lowercase value if URL decoding fails.
  }
  if (value.contains('/pronunciations/full-word/')) {
    return PronunciationAudioRole.fullWord;
  }
  if (value.contains('/pronunciations/breakdown/')) {
    return PronunciationAudioRole.breakdown;
  }
  return PronunciationAudioRole.unknown;
}

({String? fullWord, String? breakdown}) normalizePronunciationUrlPair({
  String? fullWord,
  String? breakdown,
}) {
  final full = (fullWord ?? '').trim().isEmpty ? null : fullWord!.trim();
  final br = (breakdown ?? '').trim().isEmpty ? null : breakdown!.trim();
  final fullRole = inferPronunciationAudioRole(full);
  final breakRole = inferPronunciationAudioRole(br);

  if (fullRole == PronunciationAudioRole.breakdown &&
      breakRole == PronunciationAudioRole.fullWord) {
    return (fullWord: br, breakdown: full);
  }
  if (fullRole == PronunciationAudioRole.breakdown && br == null) {
    return (fullWord: null, breakdown: full);
  }
  if (breakRole == PronunciationAudioRole.fullWord && full == null) {
    return (fullWord: br, breakdown: null);
  }

  return (fullWord: full, breakdown: br);
}

class PronunciationAudioAsset {
  final String url;
  final int? durationMs;

  const PronunciationAudioAsset({required this.url, this.durationMs});
}

class PronunciationBreakdownSegment {
  final int index;
  final String chunk;
  final String spoken;
  final int? startMs;
  final int? endMs;

  const PronunciationBreakdownSegment({
    required this.index,
    required this.chunk,
    required this.spoken,
    this.startMs,
    this.endMs,
  });

  factory PronunciationBreakdownSegment.fromJson(
    Map<String, dynamic> json,
    int fallbackIndex,
  ) {
    int? parseMs(dynamic value) => value is num ? value.round() : null;

    return PronunciationBreakdownSegment(
      index: (json['index'] as num?)?.toInt() ?? fallbackIndex,
      chunk: json['chunk']?.toString() ?? '',
      spoken: json['spoken']?.toString() ?? json['chunk']?.toString() ?? '',
      startMs: parseMs(json['startMs'] ?? json['start_ms']),
      endMs: parseMs(json['endMs'] ?? json['end_ms']),
    );
  }

  factory PronunciationBreakdownSegment.fromLegacyString(
    String value,
    int index,
  ) {
    return PronunciationBreakdownSegment(
      index: index,
      chunk: value,
      spoken: value,
    );
  }
}

class WordPronunciation {
  final String normalizedWord;
  final String? displayWord;
  final String? phoneticDisplay;
  final List<String> syllables;
  final List<PronunciationBreakdownSegment> breakdownSegments;
  final String source;
  final double? confidence;
  final bool humanReviewed;
  final PronunciationAudioAsset? breakdown;
  final PronunciationAudioAsset? fullWord;

  const WordPronunciation({
    required this.normalizedWord,
    this.displayWord,
    this.phoneticDisplay,
    this.syllables = const [],
    this.breakdownSegments = const [],
    required this.source,
    this.confidence,
    this.humanReviewed = false,
    this.breakdown,
    this.fullWord,
  });

  factory WordPronunciation.fromRow(Map<String, dynamic> row) {
    final syllablesRaw = row['syllables'];
    final syllables = syllablesRaw is List
        ? syllablesRaw
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    final breakdownSegmentsRaw = row['breakdown_segments'];
    final breakdownSegments = <PronunciationBreakdownSegment>[];
    if (breakdownSegmentsRaw is List) {
      for (var i = 0; i < breakdownSegmentsRaw.length; i++) {
        final raw = breakdownSegmentsRaw[i];
        final segment = switch (raw) {
          final Map<String, dynamic> json =>
            PronunciationBreakdownSegment.fromJson(json, i),
          final Map<dynamic, dynamic> json =>
            PronunciationBreakdownSegment.fromJson(
              json.map((key, value) => MapEntry(key.toString(), value)),
              i,
            ),
          final String value => PronunciationBreakdownSegment.fromLegacyString(
            value,
            i,
          ),
          _ => null,
        };
        if (segment != null &&
            (segment.chunk.isNotEmpty || segment.spoken.isNotEmpty)) {
          breakdownSegments.add(segment);
        }
      }
    }

    PronunciationAudioAsset? assetFromUrl(dynamic url, dynamic durationMs) {
      if (url is! String || url.isEmpty) {
        return null;
      }
      final ms = durationMs is num ? durationMs.toInt() : null;
      return PronunciationAudioAsset(url: url, durationMs: ms);
    }

    final normalizedUrls = normalizePronunciationUrlPair(
      fullWord: row['full_word_url'] as String?,
      breakdown: row['breakdown_url'] as String?,
    );

    return WordPronunciation(
      normalizedWord: (row['normalized_word'] as String?) ?? '',
      displayWord: row['display_word'] as String?,
      phoneticDisplay: row['phonetic_display'] as String?,
      syllables: syllables,
      breakdownSegments: breakdownSegments,
      source: (row['source'] as String?) ?? 'unknown',
      confidence: (row['confidence'] as num?)?.toDouble(),
      humanReviewed: row['human_reviewed'] == true,
      breakdown: assetFromUrl(
        normalizedUrls.breakdown,
        row['breakdown_duration_ms'],
      ),
      fullWord: assetFromUrl(
        normalizedUrls.fullWord,
        row['full_word_duration_ms'],
      ),
    );
  }
}

class BookPronunciationManifest {
  final String bookId;
  final Map<String, WordPronunciation> entries;

  const BookPronunciationManifest({
    required this.bookId,
    required this.entries,
  });

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;

  WordPronunciation? lookup(String? normalizedWord) {
    if (normalizedWord == null || normalizedWord.isEmpty) {
      return null;
    }
    return entries[normalizedWord];
  }
}
