import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/features/narration_studio/application/narration_track_selection.dart';
import 'package:loratone/src/features/narration_studio/domain/narration_track.dart';

TextElement _element(String id, String text) => TextElement(
  id: id,
  text: text,
  x: 10,
  y: 20,
  width: 80,
  fontFamily: 'Inter',
  fontSize: 10,
  fontWeight: 400,
  color: '#FFFFFF',
  textAlign: 'left',
  rotation: 0,
);

PageData _page(int number, {TextOverlayConfig? overlay, String? text}) => PageData(
  id: 'page-$number',
  pageNumber: number,
  textContent: text,
  overlay: overlay,
  narrationUrl: 'https://cdn.test/storia/page$number.mp3',
  narrationTimestamps: const [WordTimestamp(word: 'storia', start: 0, end: 1)],
);

Book _book(List<PageData> pages) =>
    Book(id: 'book-1', title: 'Test', pageCount: pages.length, pages: pages);

NarrationPageRecording _recording(
  int pageNumber, {
  int wordCount = 4,
  NarrationAlignment alignment = NarrationAlignment.aligned,
  String url = 'https://cdn.test/mom.m4a',
}) => NarrationPageRecording(
  pageId: 'page-$pageNumber',
  pageNumber: pageNumber,
  audioUrl: url,
  wordCount: wordCount,
  alignment: alignment,
  wordTimestamps: const [
    WordTimestamp(word: 'Once', start: 0, end: 0.5),
    WordTimestamp(word: 'upon', start: 0.5, end: 1),
    WordTimestamp(word: 'a', start: 1, end: 1.2),
    WordTimestamp(word: 'time', start: 1.2, end: 2),
  ],
);

NarrationTrack _track(List<NarrationPageRecording> pages, {bool isReady = true}) =>
    NarrationTrack(
      id: 'track-1',
      bookId: 'book-1',
      label: 'Mom',
      isReady: isReady,
      pages: pages,
    );

void main() {
  group('countRenderedWords', () {
    // PARITY FIXTURE — mirrors src/lib/narration/referenceWords.test.ts in the
    // web repo. Both tokenizers must agree or word highlighting misaligns.
    test('counts overlay elements in stored order, punctuation attached', () {
      final page = _page(
        1,
        overlay: TextOverlayConfig(
          version: 1,
          elements: [
            _element('a', 'Once upon a time,'),
            _element('b', 'a small fox   found\na lantern.'),
          ],
        ),
        text: 'Once upon a time, a small fox found a lantern.',
      );

      expect(countRenderedWords(page), 10);
    });

    test('falls back to textContent when there is no overlay', () {
      expect(countRenderedWords(_page(1, text: '  The  end.  ')), 2);
    });

    test('is zero for an image-only page', () {
      expect(countRenderedWords(_page(1)), 0);
      expect(
        countRenderedWords(
          _page(1, overlay: const TextOverlayConfig(version: 1, elements: [])),
        ),
        0,
      );
    });
  });

  group('applyTrackToBook', () {
    final page1 = _page(
      1,
      overlay: TextOverlayConfig(
        version: 1,
        elements: [_element('a', 'Once upon a time')],
      ),
    );
    final page2 = _page(
      2,
      overlay: TextOverlayConfig(
        version: 1,
        elements: [_element('b', 'The end is here')],
      ),
    );

    test('is identity when no track is selected', () {
      final book = _book([page1, page2]);

      expect(identical(applyTrackToBook(book, null), book), isTrue);
    });

    test('swaps narration url and timestamps for recorded pages', () {
      final result = applyTrackToBook(
        _book([page1, page2]),
        _track([_recording(1)]),
      );

      expect(result.pages[0].narrationUrl, 'https://cdn.test/mom.m4a');
      expect(result.pages[0].narrationTimestamps, hasLength(4));
      expect(result.pages[0].narrationTimestamps!.first.word, 'Once');
    });

    test('leaves unrecorded pages on the published Storia narration', () {
      final result = applyTrackToBook(
        _book([page1, page2]),
        _track([_recording(1)]),
      );

      expect(result.pages[1].narrationUrl, 'https://cdn.test/storia/page2.mp3');
      expect(result.pages[1].narrationTimestamps!.first.word, 'storia');
    });

    test('keeps other page fields intact', () {
      final result = applyTrackToBook(
        _book([page1, page2]),
        _track([_recording(1)]),
      );

      expect(result.pages[0].id, page1.id);
      expect(result.pages[0].overlay, same(page1.overlay));
      expect(result.pages, hasLength(2));
      expect(result.title, 'Test');
    });

    test('ignores recordings with an empty audio url', () {
      final result = applyTrackToBook(
        _book([page1]),
        _track([_recording(1, url: '')]),
      );

      expect(result.pages[0].narrationUrl, 'https://cdn.test/storia/page1.mp3');
    });

    test(
      'drops timings but keeps the voice when the page text changed since recording',
      () {
        // page1 renders 4 words; the recording was aligned against 7.
        final result = applyTrackToBook(
          _book([page1]),
          _track([_recording(1, wordCount: 7)]),
        );

        expect(result.pages[0].narrationUrl, 'https://cdn.test/mom.m4a');
        expect(result.pages[0].narrationTimestamps, isEmpty);
      },
    );
  });

  group('track selection', () {
    test('only offers ready tracks that have recordings', () {
      final tracks = [
        _track([_recording(1)], isReady: false),
        NarrationTrack(
          id: 'empty',
          bookId: 'book-1',
          label: 'Empty',
          isReady: true,
          pages: const [],
        ),
        _track([_recording(1)]),
      ];

      expect(selectableTracks(tracks).map((t) => t.id), ['track-1']);
    });

    test('falls back to the Storia voice when the selected track is gone', () {
      expect(resolveSelectedTrack([_track([_recording(1)])], 'deleted'), isNull);
      expect(resolveSelectedTrack(const [], 'track-1'), isNull);
      expect(resolveSelectedTrack([_track([_recording(1)])], null), isNull);
    });

    test('resolves a selected ready track', () {
      final track = _track([_recording(1)]);

      expect(resolveSelectedTrack([track], 'track-1')?.id, 'track-1');
    });
  });
}
