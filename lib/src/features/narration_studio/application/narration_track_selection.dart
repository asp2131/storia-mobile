import '../../../data/models.dart';
import '../domain/narration_track.dart';

/// Swaps a parent-recorded track into a book's pages.
///
/// This is the whole playback integration. The reader highlights words from
/// `PageData.narrationTimestamps` while `AudioEngine` plays
/// `PageData.narrationUrl`; replacing both keeps the highlight engine, overlay
/// layout engine, and audio engine untouched.
///
/// Pages the adult never recorded keep the published Storia narration.
Book applyTrackToBook(Book book, NarrationTrack? track) {
  if (track == null || track.pages.isEmpty) return book;

  final byPageNumber = <int, NarrationPageRecording>{
    for (final recording in track.pages)
      if (recording.audioUrl.isNotEmpty) recording.pageNumber: recording,
  };

  if (byPageNumber.isEmpty) return book;

  return book.copyWithPages([
    for (final page in book.pages)
      _applyRecording(page, byPageNumber[page.pageNumber]),
  ]);
}

PageData _applyRecording(PageData page, NarrationPageRecording? recording) {
  if (recording == null) return page;

  // Staleness guard: the recording was aligned against a word count that no
  // longer matches the page, so the book text was edited after recording.
  // Keep the voice, drop the timings — silently wrong highlighting is worse
  // than none, and the studio surfaces this page as needing a retake.
  final isStale =
      recording.wordCount > 0 &&
      recording.wordCount != countRenderedWords(page);

  return page.copyWith(
    narrationUrl: recording.audioUrl,
    narrationTimestamps: isStale
        ? const <WordTimestamp>[]
        : recording.wordTimestamps,
  );
}

/// Counts the word tokens the reader will render for a page.
///
/// PARITY: mirrors `buildPageReferenceWords()` in the web repo
/// (`src/lib/narration/referenceWords.ts`) and the token split in
/// `overlay_layout_engine.dart` — overlay elements in stored order, whitespace
/// split, no normalization. See that file's parity contract before changing.
int countRenderedWords(PageData page) {
  final overlay = page.overlay;

  if (overlay != null && overlay.elements.isNotEmpty) {
    var count = 0;
    for (final element in overlay.elements) {
      count += _tokenize(element.text).length;
    }
    if (count > 0) return count;
  }

  return _tokenize(page.textContent ?? '').length;
}

List<String> _tokenize(String raw) => raw
    .split(RegExp(r'\s+'))
    .where((token) => token.trim().isNotEmpty)
    .toList(growable: false);

/// The tracks worth offering in the voice picker.
List<NarrationTrack> selectableTracks(List<NarrationTrack> tracks) => tracks
    .where((t) => t.isReady && t.pages.isNotEmpty)
    .toList(growable: false);

/// Resolves the selected track id against what actually exists, so a deleted
/// track falls back to the published Storia voice instead of breaking playback.
NarrationTrack? resolveSelectedTrack(
  List<NarrationTrack> tracks,
  String? selectedTrackId,
) {
  if (selectedTrackId == null) return null;

  for (final track in selectableTracks(tracks)) {
    if (track.id == selectedTrackId) return track;
  }
  return null;
}
