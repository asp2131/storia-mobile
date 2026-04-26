import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:storia_kids/src/data/pronunciation_models.dart';
import 'package:storia_kids/src/data/pronunciation_repository.dart';
import 'package:storia_kids/src/features/reader/runtime/services/pronunciation_playback_service.dart';

void main() {
  group('PronunciationPlaybackService', () {
    late _FakePronunciationPlayback playback;
    late _FakePronunciationRepository repository;
    late PronunciationPlaybackService service;

    setUp(() {
      playback = _FakePronunciationPlayback();
      repository = _FakePronunciationRepository();
      service = PronunciationPlaybackService.withPlaybackCallbacks(
        playPronunciationSequence: playback.playPronunciationSequence,
        stopPronunciation: playback.stopPronunciation,
        repository: repository,
      );
    });

    test(
      'normalizes the requested word and plays breakdown before full word',
      () async {
        repository.manifest = BookPronunciationManifest(
          bookId: 'book-1',
          entries: {
            "don't": const WordPronunciation(
              normalizedWord: "don't",
              source: 'dictionary',
              breakdown: PronunciationAudioAsset(
                url: 'https://cdn/breakdown.mp3',
              ),
              fullWord: PronunciationAudioAsset(url: 'https://cdn/full.mp3'),
            ),
          },
        );

        final outcome = await service.tryPlayBreakdownFor(
          rawWord: 'Don’t!',
          bookId: 'book-1',
        );

        expect(outcome, PronunciationOutcome.played);
        expect(playback.playedSequences, [
          ['https://cdn/breakdown.mp3', 'https://cdn/full.mp3'],
        ]);
        expect(repository.requestedBookIds, ['book-1']);
      },
    );

    test('plays full word only when no breakdown URL exists', () async {
      repository.manifest = BookPronunciationManifest(
        bookId: 'book-1',
        entries: {
          'hello': const WordPronunciation(
            normalizedWord: 'hello',
            source: 'editor_override',
            fullWord: PronunciationAudioAsset(url: 'https://cdn/hello.mp3'),
          ),
        },
      );

      final outcome = await service.tryPlayBreakdownFor(
        rawWord: 'Hello.',
        bookId: 'book-1',
      );

      expect(outcome, PronunciationOutcome.played);
      expect(playback.playedSequences, [
        ['https://cdn/hello.mp3'],
      ]);
    });

    test(
      'falls back without playback for missing or unusable manifest data',
      () async {
        repository.manifest = BookPronunciationManifest(
          bookId: 'book-1',
          entries: {
            'silent': const WordPronunciation(
              normalizedWord: 'silent',
              source: 'dictionary',
            ),
          },
        );

        final emptyOutcome = await service.tryPlayBreakdownFor(
          rawWord: 'Hello',
          bookId: 'book-1',
        );
        final invalidWordOutcome = await service.tryPlayBreakdownFor(
          rawWord: '...',
          bookId: 'book-1',
        );
        final missingBookOutcome = await service.tryPlayBreakdownFor(
          rawWord: 'Hello',
          bookId: '',
        );
        final noAudioOutcome = await service.tryPlayBreakdownFor(
          rawWord: 'silent',
          bookId: 'book-1',
        );

        expect(emptyOutcome, PronunciationOutcome.fallback);
        expect(invalidWordOutcome, PronunciationOutcome.fallback);
        expect(missingBookOutcome, PronunciationOutcome.fallback);
        expect(noAudioOutcome, PronunciationOutcome.fallback);
        expect(playback.playedSequences, isEmpty);
      },
    );

    test('falls back when manifest lookup throws', () async {
      repository.throwOnLookup = true;

      final outcome = await service.tryPlayBreakdownFor(
        rawWord: 'hello',
        bookId: 'book-1',
      );

      expect(outcome, PronunciationOutcome.fallback);
      expect(playback.playedSequences, isEmpty);
      expect(playback.stopCount, 0);
    });

    test(
      'returns error and stops pronunciation if manifest audio throws',
      () async {
        repository.manifest = BookPronunciationManifest(
          bookId: 'book-1',
          entries: {
            'hello': const WordPronunciation(
              normalizedWord: 'hello',
              source: 'dictionary',
              fullWord: PronunciationAudioAsset(url: 'https://cdn/hello.mp3'),
            ),
          },
        );
        playback.throwOnPlay = true;

        final outcome = await service.tryPlayBreakdownFor(
          rawWord: 'hello',
          bookId: 'book-1',
        );

        expect(outcome, PronunciationOutcome.error);
        expect(playback.stopCount, 1);
      },
    );

    test(
      'stop delegates to pronunciation playback without TTS/native plugins',
      () async {
        await service.stop();

        expect(playback.stopCount, 1);
        expect(playback.playedSequences, isEmpty);
      },
    );
  });

  group('BookPronunciationManifest.lookup', () {
    test(
      'returns entries by normalized word and ignores null or empty keys',
      () {
        const pronunciation = WordPronunciation(
          normalizedWord: 'hello',
          source: 'dictionary',
          fullWord: PronunciationAudioAsset(url: 'https://cdn/hello.mp3'),
        );
        const manifest = BookPronunciationManifest(
          bookId: 'book-1',
          entries: {'hello': pronunciation},
        );

        expect(manifest.lookup('hello'), same(pronunciation));
        expect(manifest.lookup('Hello'), isNull);
        expect(manifest.lookup(''), isNull);
        expect(manifest.lookup(null), isNull);
      },
    );
  });
}

class _FakePronunciationPlayback {
  final List<List<String>> playedSequences = [];
  var stopCount = 0;
  var throwOnPlay = false;

  Future<void> playPronunciationSequence(List<String> urls) async {
    if (throwOnPlay) {
      throw StateError('audio failed');
    }
    playedSequences.add(List<String>.of(urls));
  }

  Future<void> stopPronunciation() async {
    stopCount++;
  }
}

class _FakePronunciationRepository extends PronunciationRepository {
  _FakePronunciationRepository()
    : super(SupabaseClient('https://example.supabase.co', 'anon-key'));

  BookPronunciationManifest? manifest;
  final List<String> requestedBookIds = [];
  var throwOnLookup = false;

  @override
  Future<BookPronunciationManifest?> getManifestForBook(String bookId) async {
    requestedBookIds.add(bookId);
    if (throwOnLookup) {
      throw StateError('manifest failed');
    }
    return manifest;
  }
}
