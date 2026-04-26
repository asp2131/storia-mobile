import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pronunciation_models.dart';

class PronunciationRepository {
  PronunciationRepository(this._supabase);

  final SupabaseClient _supabase;
  final Map<String, BookPronunciationManifest> _cache = {};
  final Map<String, Future<BookPronunciationManifest?>> _inflight = {};
  final Map<String, DateTime> _failureCooldownUntil = {};

  static const Duration failureCooldown = Duration(seconds: 10);
  static const _consumableStatuses = {'generated', 'reviewed'};

  Future<BookPronunciationManifest?> getManifestForBook(String bookId) async {
    if (bookId.isEmpty) {
      return null;
    }

    final cached = _cache[bookId];
    if (cached != null && cached.isNotEmpty) {
      debugPrint(
        '[PronunciationRepository] CACHE HIT book=$bookId entries=${cached.entries.length}',
      );
      return cached;
    }
    if (cached != null && cached.isEmpty) {
      debugPrint(
        '[PronunciationRepository] cache had empty manifest for book=$bookId — refetching',
      );
      _cache.remove(bookId);
    }

    final cooldownUntil = _failureCooldownUntil[bookId];
    if (cooldownUntil != null && DateTime.now().isBefore(cooldownUntil)) {
      debugPrint(
        '[PronunciationRepository] in cooldown for book=$bookId until $cooldownUntil',
      );
      return null;
    }

    final inflight = _inflight[bookId];
    if (inflight != null) {
      return inflight;
    }

    final future = _fetch(bookId);
    _inflight[bookId] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(bookId);
    }
  }

  Future<BookPronunciationManifest?> _fetch(String bookId) async {
    try {
      final data = await _supabase
          .from('book_pronunciations')
          .select(
            'normalized_word, display_word, phonetic_display, syllables, '
            'breakdown_segments, full_word_url, breakdown_url, source, '
            'status, confidence, human_reviewed',
          )
          .eq('book_id', bookId);

      final rowsList = (data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
      debugPrint(
        '[PronunciationRepository] book=$bookId rows=${rowsList.length}',
      );
      final entries = <String, WordPronunciation>{};
      var skippedStatus = 0;
      var skippedNoUrl = 0;
      for (final row in rowsList) {
        final status = (row['status'] as String?)?.toLowerCase() ?? '';
        if (!_consumableStatuses.contains(status)) {
          skippedStatus++;
          continue;
        }
        final pronunciation = WordPronunciation.fromRow(row);
        if (pronunciation.normalizedWord.isEmpty) {
          continue;
        }
        if (pronunciation.fullWord == null && pronunciation.breakdown == null) {
          skippedNoUrl++;
          continue;
        }
        entries[pronunciation.normalizedWord] = pronunciation;
      }
      debugPrint(
        '[PronunciationRepository] book=$bookId entries=${entries.length} '
        'skippedStatus=$skippedStatus skippedNoUrl=$skippedNoUrl',
      );

      final manifest = BookPronunciationManifest(
        bookId: bookId,
        entries: entries,
      );
      _cache[bookId] = manifest;
      _failureCooldownUntil.remove(bookId);
      return manifest;
    } catch (error, stack) {
      debugPrint('[PronunciationRepository] fetch failed for $bookId: $error');
      debugPrintStack(stackTrace: stack);
      _failureCooldownUntil[bookId] = DateTime.now().add(failureCooldown);
      return null;
    }
  }

  void invalidate(String bookId) {
    _cache.remove(bookId);
    _failureCooldownUntil.remove(bookId);
  }

  void clear() {
    _cache.clear();
    _failureCooldownUntil.clear();
  }
}
