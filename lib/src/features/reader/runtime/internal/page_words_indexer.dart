import '../../../../data/models.dart';

Map<String, List<int>> buildWordToIndices(PageData page) {
  final wordToIndices = <String, List<int>>{};
  var index = 0;

  final timestamps = page.narrationTimestamps;
  if (timestamps != null && timestamps.isNotEmpty) {
    for (final ts in timestamps) {
      final word = _cleanWord(ts.word);
      if (word.isNotEmpty) {
        wordToIndices.putIfAbsent(word, () => []).add(index);
        index++;
      }
    }
    return wordToIndices;
  }

  if (page.overlay != null) {
    for (final element in page.overlay!.elements) {
      final tokens = element.text
          .split(RegExp(r'\s+'))
          .where((t) => t.trim().isNotEmpty);
      for (final token in tokens) {
        final word = _cleanWord(token);
        if (word.isNotEmpty) {
          wordToIndices.putIfAbsent(word, () => []).add(index);
          index++;
        }
      }
    }
    return wordToIndices;
  }

  final text = page.textContent;
  if (text != null && text.trim().isNotEmpty) {
    final tokens = text.split(RegExp(r'\s+')).where((t) => t.trim().isNotEmpty);
    for (final token in tokens) {
      final word = _cleanWord(token);
      if (word.isNotEmpty) {
        wordToIndices.putIfAbsent(word, () => []).add(index);
        index++;
      }
    }
  }

  return wordToIndices;
}

String _cleanWord(String word) =>
    word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
