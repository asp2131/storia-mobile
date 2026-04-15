import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Storia_Kids/src/data/models.dart';
import 'package:Storia_Kids/src/features/progress/domain/book_progress.dart';
import 'package:Storia_Kids/src/features/progress/domain/continue_reading_item.dart';
import 'package:Storia_Kids/src/features/library/widgets/continue_reading_card.dart';

void main() {
  testWidgets('renders continue reading details and actions', (tester) async {
    var resumed = false;
    var played = false;

    final item = ContinueReadingItem(
      book: const Book(
        id: 'book-1',
        title: 'Moon Stories',
        author: 'A. Author',
        pageCount: 24,
        pages: [],
      ),
      progress: const BookProgress(
        childProfileId: 'child-1',
        bookId: 'book-1',
        currentPage: 7,
        totalPages: 24,
        progressPercent: 29,
        completionCount: 0,
        status: BookProgressStatus.inProgress,
      ),
      hasNarration: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContinueReadingCard(
            item: item,
            onResume: () => resumed = true,
            onPlay: () => played = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Continue Reading'), findsOneWidget);
    expect(find.text('Moon Stories'), findsOneWidget);
    expect(find.text('Page 7 of 24'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(resumed, isTrue);

    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(played, isTrue);
  });
}
