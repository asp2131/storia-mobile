import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../audio/audio_engine.dart';
import '../../../../data/pronunciation_models.dart';
import '../../../../data/pronunciation_repository.dart';
import '../internal/word_normalizer.dart';

enum PronunciationOutcome {
  /// Manifest entry was found and the audio sequence either completed or
  /// was cancelled cleanly. No fallback needed.
  played,

  /// Manifest had no usable entry for this word. Caller should fall back to
  /// the on-device TTS path (e.g. `WordTtsService.soundOut`).
  fallback,

  /// Manifest entry existed but audio playback errored (fetch / decode).
  /// Caller may attempt fallback to TTS.
  error,
}

class PronunciationPlaybackPlan {
  const PronunciationPlaybackPlan({
    required this.entry,
    required this.urls,
    required this.includesBreakdown,
  });

  final WordPronunciation entry;
  final List<String> urls;
  final bool includesBreakdown;
}

/// Owns the manifest-first long-press playback path. Has no UI state of its
/// own — orchestration of highlight + narration capture/restore lives in
/// `WordTtsNotifier`.
class PronunciationPlaybackService {
  PronunciationPlaybackService({
    required AudioEngine audioEngine,
    required PronunciationRepository repository,
  }) : this.withPlaybackCallbacks(
         playPronunciationSequence: audioEngine.playPronunciationSequence,
         stopPronunciation: audioEngine.stopPronunciation,
         pronunciationPosition: audioEngine.pronunciationPosition,
         repository: repository,
       );

  PronunciationPlaybackService.withPlaybackCallbacks({
    required Future<void> Function(List<String> urls) playPronunciationSequence,
    required Future<void> Function() stopPronunciation,
    required PronunciationRepository repository,
    Stream<Duration>? pronunciationPosition,
  }) : _playPronunciationSequence = playPronunciationSequence,
       _stopPronunciation = stopPronunciation,
       _repository = repository,
       _pronunciationPosition = pronunciationPosition ?? const Stream.empty();

  final Future<void> Function(List<String> urls) _playPronunciationSequence;
  final Future<void> Function() _stopPronunciation;
  final PronunciationRepository _repository;
  final Stream<Duration> _pronunciationPosition;

  Stream<Duration> get pronunciationPosition => _pronunciationPosition;

  /// Resolves `rawWord` against the manifest for `bookId` and plays the
  /// breakdown → fullWord sequence on the dedicated pronunciation channel.
  Future<PronunciationOutcome> tryPlayBreakdownFor({
    required String rawWord,
    required String bookId,
    void Function(PronunciationPlaybackPlan plan)? onPlaybackReady,
  }) async {
    final normalized = normalizeWordToken(rawWord);
    if (normalized == null) {
      debugPrint('[Pronunciation] raw="$rawWord" normalized=null → fallback');
      return PronunciationOutcome.fallback;
    }
    if (bookId.isEmpty) {
      debugPrint(
        '[Pronunciation] bookId empty for word=$normalized → fallback',
      );
      return PronunciationOutcome.fallback;
    }

    BookPronunciationManifest? manifest;
    try {
      manifest = await _repository.getManifestForBook(bookId);
    } catch (e) {
      debugPrint('[Pronunciation] manifest fetch threw: $e → fallback');
      return PronunciationOutcome.fallback;
    }
    if (manifest == null || manifest.isEmpty) {
      debugPrint(
        '[Pronunciation] manifest null/empty for book=$bookId → fallback',
      );
      return PronunciationOutcome.fallback;
    }

    final entry = manifest.lookup(normalized);
    if (entry == null) {
      debugPrint(
        '[Pronunciation] no entry for "$normalized" '
        '(manifest has ${manifest.entries.length} entries) → fallback',
      );
      return PronunciationOutcome.fallback;
    }

    final urls = <String>[];
    var includesBreakdown = false;
    final breakdownUrl = entry.breakdown?.url;
    final fullWordUrl = entry.fullWord?.url;
    if (breakdownUrl != null && breakdownUrl.isNotEmpty) {
      urls.add(breakdownUrl);
      includesBreakdown = true;
    }
    if (fullWordUrl != null && fullWordUrl.isNotEmpty) {
      urls.add(fullWordUrl);
    }
    if (urls.isEmpty) {
      debugPrint(
        '[Pronunciation] entry for "$normalized" has no URLs → fallback',
      );
      return PronunciationOutcome.fallback;
    }

    final plan = PronunciationPlaybackPlan(
      entry: entry,
      urls: List.unmodifiable(urls),
      includesBreakdown: includesBreakdown,
    );
    onPlaybackReady?.call(plan);

    try {
      debugPrint('[Pronunciation] playing "$normalized" urls=${urls.length}');
      await _playPronunciationSequence(urls);
      return PronunciationOutcome.played;
    } catch (e) {
      debugPrint('[Pronunciation] playback error: $e → error/fallback');
      try {
        await _stopPronunciation();
      } catch (_) {}
      return PronunciationOutcome.error;
    }
  }

  Future<void> stop() => _stopPronunciation();
}
