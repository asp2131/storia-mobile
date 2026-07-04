import '../../../data/models.dart';

/// Immutable, session-scoped summary shown on the book-finished celebration
/// screen. v1 celebrates only what the reader already knows this session —
/// the book, how many pages, and how long. Story Sparks results are
/// intentionally omitted for v1.
class BookCelebrationSummary {
  const BookCelebrationSummary({
    required this.bookTitle,
    required this.coverUrl,
    required this.pagesRead,
    required this.timeRead,
  });

  final String bookTitle;
  final String? coverUrl;
  final int pagesRead;
  final Duration timeRead;

  /// Builds a summary from the finished [book] and the elapsed reading time.
  /// Negative durations (clock skew) clamp to zero.
  factory BookCelebrationSummary.fromBook(
    Book book, {
    required Duration timeRead,
  }) {
    return BookCelebrationSummary(
      bookTitle: book.title,
      coverUrl: book.coverUrl,
      pagesRead: book.pages.length,
      timeRead: timeRead.isNegative ? Duration.zero : timeRead,
    );
  }

  /// Whole minutes read, floored, but never less than 1 — a quick finish
  /// still reads "1 min" rather than "0 min".
  int get minutesRead {
    final m = timeRead.inMinutes;
    return m < 1 ? 1 : m;
  }
}
