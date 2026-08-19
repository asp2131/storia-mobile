import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/features/narration_studio/application/narration_track_selection.dart';
import 'package:loratone/src/features/narration_studio/domain/narration_track.dart';
import 'package:loratone/src/features/reader/overlay/text_overlay_utils.dart';

/// The feature's actual acceptance criterion: with a parent track selected, the
/// reader's existing highlight math must track the parent's timings, not the
/// published narration's.
void main() {
  const overlay = TextOverlayConfig(
    version: 1,
    elements: [
      TextElement(
        id: 'line-1',
        text: 'Once upon a time',
        x: 10,
        y: 20,
        width: 80,
        fontFamily: 'Inter',
        fontSize: 10,
        fontWeight: 400,
        color: '#FFFFFF',
        textAlign: 'left',
        rotation: 0,
      ),
    ],
  );

  // Storia's TTS reads the line in 2s; the parent reads it slowly, in 8s.
  const storiaTimings = [
    WordTimestamp(word: 'Once', start: 0, end: 0.5),
    WordTimestamp(word: 'upon', start: 0.5, end: 1),
    WordTimestamp(word: 'a', start: 1, end: 1.5),
    WordTimestamp(word: 'time', start: 1.5, end: 2),
  ];

  const parentTimings = [
    WordTimestamp(word: 'Once', start: 0, end: 2),
    WordTimestamp(word: 'upon', start: 2, end: 4),
    WordTimestamp(word: 'a', start: 4, end: 6),
    WordTimestamp(word: 'time', start: 6, end: 8),
  ];

  final book = Book(
    id: 'book-1',
    title: 'Test',
    pageCount: 1,
    pages: const [
      PageData(
        id: 'page-1',
        pageNumber: 1,
        overlay: overlay,
        narrationUrl: 'https://cdn.test/storia.mp3',
        narrationTimestamps: storiaTimings,
      ),
    ],
  );

  final parentTrack = NarrationTrack(
    id: 'track-1',
    bookId: 'book-1',
    label: 'Mom',
    isReady: true,
    pages: const [
      NarrationPageRecording(
        pageId: 'page-1',
        pageNumber: 1,
        audioUrl: 'https://cdn.test/mom.m4a',
        wordCount: 4,
        alignment: NarrationAlignment.aligned,
        wordTimestamps: parentTimings,
      ),
    ],
  );

  test('reader plays the parent recording once a track is applied', () {
    final page = applyTrackToBook(book, parentTrack).pages.single;

    expect(page.narrationUrl, 'https://cdn.test/mom.m4a');
  });

  test('active word index follows the parent timings, not the Storia ones', () {
    final page = applyTrackToBook(book, parentTrack).pages.single;

    // At 3s the fast Storia track would be past the end; the parent is on word 1.
    expect(
      computeActiveWordIndex(page.narrationTimestamps, const Duration(seconds: 3)),
      1,
    );
    expect(
      computeActiveWordIndex(page.narrationTimestamps, const Duration(seconds: 5)),
      2,
    );
    expect(
      computeActiveWordIndex(page.narrationTimestamps, const Duration(seconds: 7)),
      3,
    );
  });

  test('the same positions resolve differently on the published narration', () {
    final page = book.pages.single;

    expect(
      computeActiveWordIndex(page.narrationTimestamps, const Duration(seconds: 3)),
      3,
    );
  });

  test('highlighting is disabled, not wrong, when the timings are stale', () {
    final staleTrack = NarrationTrack(
      id: 'track-2',
      bookId: 'book-1',
      label: 'Mom',
      isReady: true,
      pages: [
        // Recorded when the page had 9 words; it renders 4 now.
        NarrationPageRecording(
          pageId: 'page-1',
          pageNumber: 1,
          audioUrl: 'https://cdn.test/mom.m4a',
          wordCount: 9,
          alignment: NarrationAlignment.aligned,
          wordTimestamps: parentTimings,
        ),
      ],
    );

    final page = applyTrackToBook(book, staleTrack).pages.single;

    expect(page.narrationUrl, 'https://cdn.test/mom.m4a');
    expect(
      computeActiveWordIndex(page.narrationTimestamps, const Duration(seconds: 3)),
      -1,
    );
  });
}
