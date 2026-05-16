import 'gen_ui_activity.dart';
import 'gen_ui_card_schema.dart';

class GenUiPromptPolicy {
  GenUiPromptPolicy({
    this.skipBackoffThreshold = 3,
    this.backoffPageModulo = 2,
  });

  final int skipBackoffThreshold;
  final int backoffPageModulo;

  bool shouldPrompt({required int pageIndex, required GenUiActivityLog log}) {
    if (log.consecutiveSkips < skipBackoffThreshold) return true;
    return pageIndex % backoffPageModulo == 0;
  }

  GenUiCardSchema? chooseCard({
    required List<GenUiCardSchema> candidates,
    required GenUiActivityLog log,
    int? pageIndex,
  }) {
    if (pageIndex != null && !shouldPrompt(pageIndex: pageIndex, log: log)) {
      return null;
    }

    final valid = candidates
        .where((card) => card.validation.isValid)
        .where((card) => !log.hasInteractedWith(card.id))
        .toList(growable: false);
    if (valid.isEmpty) return null;

    final counts = log.answeredCountsByType;
    if (counts.isEmpty) return valid.first;

    valid.sort((a, b) {
      final aCount = counts[a.type] ?? 0;
      final bCount = counts[b.type] ?? 0;
      return bCount.compareTo(aCount);
    });
    return valid.first;
  }
}
