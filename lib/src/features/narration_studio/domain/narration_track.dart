import 'package:flutter/foundation.dart';

import '../../../data/models.dart';

/// How much to trust a recording's word timings.
///
/// Mirrors `alignment_status` on the server (`src/lib/narration/alignRecording.ts`).
enum NarrationAlignment {
  /// One timing per rendered word, straight from forced alignment.
  aligned,

  /// The aligner disagreed on word count; timings were projected. May drift.
  projected,

  /// Alignment unavailable — timings are duration-proportional guesses.
  fallback,

  /// Recorded but not yet aligned.
  pending,

  /// Alignment failed outright.
  failed;

  static NarrationAlignment fromJson(String? raw) {
    return switch (raw) {
      'aligned' => NarrationAlignment.aligned,
      'projected' => NarrationAlignment.projected,
      'fallback' => NarrationAlignment.fallback,
      'failed' => NarrationAlignment.failed,
      _ => NarrationAlignment.pending,
    };
  }

  /// Whether highlighting from this recording is worth showing without a nudge.
  bool get isReliable =>
      this == NarrationAlignment.aligned ||
      this == NarrationAlignment.projected;
}

@immutable
class NarrationPageRecording {
  const NarrationPageRecording({
    required this.pageId,
    required this.pageNumber,
    required this.audioUrl,
    required this.wordTimestamps,
    required this.wordCount,
    required this.alignment,
    this.durationMs,
  });

  final String pageId;
  final int pageNumber;
  final String audioUrl;
  final List<WordTimestamp> wordTimestamps;

  /// Rendered word count this recording was aligned against. When it no longer
  /// matches the page's words, the book text changed and the timings are stale.
  final int wordCount;

  final NarrationAlignment alignment;
  final int? durationMs;

  factory NarrationPageRecording.fromJson(Map<String, dynamic> json) {
    final rawTimestamps = json['wordTimestamps'];
    return NarrationPageRecording(
      pageId: json['pageId']?.toString() ?? '',
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 0,
      audioUrl: json['audioUrl'] as String? ?? '',
      wordTimestamps: rawTimestamps is List
          ? rawTimestamps
                .whereType<Map<String, dynamic>>()
                .map(WordTimestamp.fromJson)
                .toList(growable: false)
          : const <WordTimestamp>[],
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
      alignment: NarrationAlignment.fromJson(
        json['alignmentStatus'] as String?,
      ),
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );
  }
}

@immutable
class NarrationTrack {
  const NarrationTrack({
    required this.id,
    required this.bookId,
    required this.label,
    required this.isReady,
    required this.pages,
  });

  final String id;
  final String bookId;

  /// What the child sees in the voice picker — "Mom", "Ms. Rivera".
  final String label;

  /// The adult marked the track finished. Draft tracks stay out of the picker.
  final bool isReady;

  final List<NarrationPageRecording> pages;

  NarrationPageRecording? pageFor(int pageNumber) {
    for (final page in pages) {
      if (page.pageNumber == pageNumber) return page;
    }
    return null;
  }

  factory NarrationTrack.fromJson(Map<String, dynamic> json) {
    final rawPages = json['pages'];
    return NarrationTrack(
      id: json['id']?.toString() ?? '',
      bookId: json['bookId']?.toString() ?? '',
      label: json['label'] as String? ?? 'My voice',
      isReady: json['status'] == 'ready',
      pages: rawPages is List
          ? rawPages
                .whereType<Map<String, dynamic>>()
                .map(NarrationPageRecording.fromJson)
                .toList(growable: false)
          : const <NarrationPageRecording>[],
    );
  }
}
