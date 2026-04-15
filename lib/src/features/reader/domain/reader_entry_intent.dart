enum ReaderEntryIntent {
  standard('standard'),
  autoplayNarration('autoplay_narration');

  const ReaderEntryIntent(this.value);
  final String value;

  static ReaderEntryIntent fromString(String? value) {
    return switch (value) {
      'autoplay_narration' => ReaderEntryIntent.autoplayNarration,
      _ => ReaderEntryIntent.standard,
    };
  }
}
