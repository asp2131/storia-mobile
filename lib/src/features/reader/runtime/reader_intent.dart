import '../../../data/models.dart';

sealed class ReaderIntent {
  const ReaderIntent();
}

final class ReaderStart extends ReaderIntent {
  const ReaderStart({required this.book, this.initialPageIndex = 0});

  final Book book;
  final int initialPageIndex;
}

final class ReaderGoToPage extends ReaderIntent {
  const ReaderGoToPage(this.pageIndex);

  final int pageIndex;
}

final class ReaderToggleNarration extends ReaderIntent {
  const ReaderToggleNarration();
}

final class ReaderToggleSoundscape extends ReaderIntent {
  const ReaderToggleSoundscape();
}

final class ReaderSetNarrationVolume extends ReaderIntent {
  const ReaderSetNarrationVolume(this.volume);

  final double volume;
}

final class ReaderSetSoundscapeVolume extends ReaderIntent {
  const ReaderSetSoundscapeVolume(this.volume);

  final double volume;
}

/// Primary CTA behavior in Reader top bar:
/// - If practice mode is off: enable practice and start listening.
/// - If practice mode is on and listening: stop listening.
/// - If practice mode is on and idle: start listening.
final class ReaderPracticePrimaryAction extends ReaderIntent {
  const ReaderPracticePrimaryAction();
}

final class ReaderAckCelebration extends ReaderIntent {
  const ReaderAckCelebration();
}
