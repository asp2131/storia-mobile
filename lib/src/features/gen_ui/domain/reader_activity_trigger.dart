import 'gen_ui_card_schema.dart';

/// Decides whether the active page's chosen activity card should be shown now.
///
/// Rules (see spec 2026-05-26-story-spark-takeover-design.md):
/// - No card -> never live.
/// - Null anchor -> live on page load.
/// - Narration off (self-read MVP) -> live on page load (no within-page signal).
/// - Narration on (read-aloud) -> live once the active narrated word index
///   reaches the card's anchor. If the child swipes away first, the card is
///   simply never live for that pass (defer/skip).
///
/// [activeNarratedWordIndex] is the result of
/// `computeActiveWordIndex(page.narrationTimestamps, narrationPosition)`
/// (-1 when there is no active word / no timestamps).
bool isActivityLive({
  required GenUiCardSchema? card,
  required bool isNarrationPlaying,
  required int activeNarratedWordIndex,
}) {
  if (card == null) return false;
  final anchor = card.anchorWordIndex;
  if (anchor == null) return true;
  if (!isNarrationPlaying) return true;
  return activeNarratedWordIndex >= anchor;
}
