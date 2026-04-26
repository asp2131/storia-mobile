class PronunciationAudioAsset {
  final String url;
  final int? durationMs;

  const PronunciationAudioAsset({required this.url, this.durationMs});
}

class WordPronunciation {
  final String normalizedWord;
  final String? displayWord;
  final String? phoneticDisplay;
  final List<String> syllables;
  final List<String>? breakdownSegments;
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
    this.breakdownSegments,
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
    final breakdownSegments = breakdownSegmentsRaw is List
        ? breakdownSegmentsRaw
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
        : null;

    PronunciationAudioAsset? assetFromUrl(dynamic url, dynamic durationMs) {
      if (url is! String || url.isEmpty) {
        return null;
      }
      final ms = durationMs is num ? durationMs.toInt() : null;
      return PronunciationAudioAsset(url: url, durationMs: ms);
    }

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
        row['breakdown_url'],
        row['breakdown_duration_ms'],
      ),
      fullWord: assetFromUrl(
        row['full_word_url'],
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
