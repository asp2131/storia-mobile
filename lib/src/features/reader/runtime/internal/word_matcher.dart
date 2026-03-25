Set<int> matchSpokenWords({
  required String recognizedWords,
  required Map<String, List<int>> wordToIndices,
  required Set<int> existingIndices,
}) {
  final spokenWords = recognizedWords
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);

  final matched = <int>{};
  for (final word in spokenWords) {
    final indices = wordToIndices[word];
    if (indices != null) {
      matched.addAll(indices);
    }
  }

  return {...existingIndices, ...matched};
}
