/// Mirrors the normalization rules used by the web/backend pipeline so
/// that `book_pronunciations.normalized_word` keys line up.
///
/// Rules:
/// - trim whitespace
/// - smart quotes folded to ASCII apostrophes
/// - Unicode NFC (Dart strings are already canonical-compatible for our use)
/// - lowercase (locale-insensitive `toLowerCase`)
/// - strip leading/trailing non-letter characters
/// - preserve internal `'` and `-`
/// - return null when no letters remain
library;

final _leadingStripPattern = RegExp(
  r"^[^\p{L}]+",
  unicode: true,
);
final _trailingStripPattern = RegExp(
  r"[^\p{L}]+$",
  unicode: true,
);
final _hasLetterPattern = RegExp(r"\p{L}", unicode: true);

String? normalizeWordToken(String raw) {
  if (raw.isEmpty) {
    return null;
  }

  var token = raw.trim();
  if (token.isEmpty) {
    return null;
  }

  token = token
      .replaceAll('’', "'")
      .replaceAll('‘', "'")
      .replaceAll('‛', "'")
      .replaceAll('＇', "'")
      .replaceAll('ʼ', "'");

  token = token.toLowerCase();
  token = token.replaceFirst(_leadingStripPattern, '');
  token = token.replaceFirst(_trailingStripPattern, '');

  if (token.isEmpty) {
    return null;
  }

  if (!_hasLetterPattern.hasMatch(token)) {
    return null;
  }

  return token;
}
