import 'package:flutter_test/flutter_test.dart';

import 'package:loratone/src/data/pronunciation_models.dart';

void main() {
  group('WordPronunciation.fromRow', () {
    test('corrects swapped full-word and breakdown storage URLs', () {
      final pronunciation = WordPronunciation.fromRow({
        'normalized_word': 'caption',
        'source': 'generated',
        'full_word_url':
            'https://cdn.example/storage/v1/object/public/storia/books/42/pronunciations/breakdown/word_caption.mp3',
        'breakdown_url':
            'https://cdn.example/storage/v1/object/public/storia/books/42/pronunciations/full-word/word_caption.mp3',
      });

      expect(
        pronunciation.breakdown?.url,
        'https://cdn.example/storage/v1/object/public/storia/books/42/pronunciations/breakdown/word_caption.mp3',
      );
      expect(
        pronunciation.fullWord?.url,
        'https://cdn.example/storage/v1/object/public/storia/books/42/pronunciations/full-word/word_caption.mp3',
      );
    });

    test(
      'parses rich breakdown timing metadata and legacy segment strings',
      () {
        final pronunciation = WordPronunciation.fromRow({
          'normalized_word': 'butterfly',
          'display_word': 'Butterfly',
          'phonetic_display': 'but-ter-fly',
          'syllables': ['but', '', 'ter', null, 'fly'],
          'source': 'generated',
          'confidence': 0.91,
          'human_reviewed': true,
          'breakdown_segments': [
            {
              'index': 10,
              'chunk': 'but',
              'spoken': 'but',
              'startMs': 0.4,
              'endMs': 240.6,
            },
            {'chunk': 'ter', 'spoken': 'tur', 'start_ms': 241, 'end_ms': 520},
            'fly',
            {'chunk': '', 'spoken': ''},
            42,
          ],
        });

        expect(pronunciation.displayWord, 'Butterfly');
        expect(pronunciation.phoneticDisplay, 'but-ter-fly');
        expect(pronunciation.syllables, ['but', 'ter', 'fly']);
        expect(pronunciation.confidence, 0.91);
        expect(pronunciation.humanReviewed, isTrue);
        expect(pronunciation.breakdownSegments, hasLength(3));

        expect(pronunciation.breakdownSegments[0].index, 10);
        expect(pronunciation.breakdownSegments[0].chunk, 'but');
        expect(pronunciation.breakdownSegments[0].spoken, 'but');
        expect(pronunciation.breakdownSegments[0].startMs, 0);
        expect(pronunciation.breakdownSegments[0].endMs, 241);

        expect(pronunciation.breakdownSegments[1].index, 1);
        expect(pronunciation.breakdownSegments[1].chunk, 'ter');
        expect(pronunciation.breakdownSegments[1].spoken, 'tur');
        expect(pronunciation.breakdownSegments[1].startMs, 241);
        expect(pronunciation.breakdownSegments[1].endMs, 520);

        expect(pronunciation.breakdownSegments[2].index, 2);
        expect(pronunciation.breakdownSegments[2].chunk, 'fly');
        expect(pronunciation.breakdownSegments[2].spoken, 'fly');
        expect(pronunciation.breakdownSegments[2].startMs, isNull);
        expect(pronunciation.breakdownSegments[2].endMs, isNull);
      },
    );

    test('infers URL roles from decoded Supabase pronunciation paths', () {
      expect(
        inferPronunciationAudioRole(
          'https://cdn/storage/v1/object/public/storia/books/1/pronunciations/full-word/hello.mp3',
        ),
        PronunciationAudioRole.fullWord,
      );
      expect(
        inferPronunciationAudioRole(
          'https://cdn/storage/v1/object/public/storia/books/1/pronunciations%2Fbreakdown%2Fhello.mp3',
        ),
        PronunciationAudioRole.breakdown,
      );
      expect(
        inferPronunciationAudioRole('https://cdn/hello.mp3'),
        PronunciationAudioRole.unknown,
      );
    });
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
