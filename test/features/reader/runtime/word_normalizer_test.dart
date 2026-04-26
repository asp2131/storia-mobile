import 'package:flutter_test/flutter_test.dart';

import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/reader/runtime/internal/page_words_indexer.dart';
import 'package:storia_kids/src/features/reader/runtime/internal/word_normalizer.dart';

void main() {
  group('normalizeWordToken', () {
    test('lowercases and strips leading/trailing punctuation', () {
      expect(normalizeWordToken('  Hello. '), 'hello');
      expect(normalizeWordToken('“Hello!”'), 'hello');
      expect(normalizeWordToken('(World)'), 'world');
      expect(normalizeWordToken('--rocket--'), 'rocket');
    });

    test('preserves internal apostrophes and hyphens', () {
      expect(normalizeWordToken("Don't"), "don't");
      expect(normalizeWordToken('high-tech'), 'high-tech');
      expect(normalizeWordToken("rock-'n'-roll"), "rock-'n'-roll");
    });

    test('folds smart apostrophes and strips leading quote punctuation', () {
      expect(normalizeWordToken('Don’t'), "don't");
      expect(normalizeWordToken('‘tis'), 'tis');
      expect(normalizeWordToken('ʼcause'), 'cause');
    });

    test('returns null for empty or punctuation-only/non-letter tokens', () {
      expect(normalizeWordToken(''), isNull);
      expect(normalizeWordToken('   '), isNull);
      expect(normalizeWordToken('...'), isNull);
      expect(normalizeWordToken('123'), isNull);
      expect(normalizeWordToken("'---'"), isNull);
    });

    test('keeps unicode letters', () {
      expect(normalizeWordToken('Éclair!'), 'éclair');
      expect(normalizeWordToken('niño'), 'niño');
      expect(normalizeWordToken('¿Qué?'), 'qué');
    });
  });

  group('buildWordToIndices', () {
    test(
      'indexes normalized timestamp words and skips punctuation-only tokens',
      () {
        const page = PageData(
          id: 'page-1',
          pageNumber: 1,
          narrationTimestamps: [
            WordTimestamp(word: 'Hello.', start: 0, end: 1),
            WordTimestamp(word: '...', start: 1, end: 2),
            WordTimestamp(word: 'Don’t', start: 2, end: 3),
            WordTimestamp(word: 'hello', start: 3, end: 4),
          ],
        );

        expect(buildWordToIndices(page), {
          'hello': [0, 2],
          "don't": [1],
        });
      },
    );

    test(
      'falls back to text content when timestamps and overlay are absent',
      () {
        const page = PageData(
          id: 'page-2',
          pageNumber: 2,
          textContent: 'Hello, hello! ... high-tech',
        );

        expect(buildWordToIndices(page), {
          'hello': [0, 1],
          'high-tech': [2],
        });
      },
    );
  });
}
