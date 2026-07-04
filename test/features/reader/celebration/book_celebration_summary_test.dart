import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/features/reader/celebration/book_celebration_summary.dart';

Book _book({int pages = 12, String? cover}) => Book(
  id: 'b1',
  title: 'The Brave Little Fox',
  coverUrl: cover,
  pageCount: pages,
  pages: List.generate(pages, (i) => PageData(id: 'p$i', pageNumber: i + 1)),
);

void main() {
  group('BookCelebrationSummary.fromBook', () {
    test('maps title, cover and page count', () {
      final s = BookCelebrationSummary.fromBook(
        _book(pages: 12, cover: 'https://x/cover.png'),
        timeRead: const Duration(minutes: 8),
      );
      expect(s.bookTitle, 'The Brave Little Fox');
      expect(s.coverUrl, 'https://x/cover.png');
      expect(s.pagesRead, 12);
      expect(s.timeRead, const Duration(minutes: 8));
    });

    test('clamps negative reading time to zero', () {
      final s = BookCelebrationSummary.fromBook(
        _book(),
        timeRead: const Duration(seconds: -30),
      );
      expect(s.timeRead, Duration.zero);
    });
  });

  group('minutesRead', () {
    test('floors to whole minutes', () {
      const s = BookCelebrationSummary(
        bookTitle: 't',
        coverUrl: null,
        pagesRead: 1,
        timeRead: Duration(minutes: 8, seconds: 59),
      );
      expect(s.minutesRead, 8);
    });

    test('is at least 1 for a quick finish', () {
      const s = BookCelebrationSummary(
        bookTitle: 't',
        coverUrl: null,
        pagesRead: 1,
        timeRead: Duration(seconds: 20),
      );
      expect(s.minutesRead, 1);
    });
  });
}
