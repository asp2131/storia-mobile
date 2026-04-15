import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Storia_Kids/src/data/models.dart';
import 'package:Storia_Kids/src/features/library/game/book_preview_overlay.dart';
import 'package:Storia_Kids/src/features/progress/domain/book_progress.dart';

void main() {
  testWidgets('shows in-progress status with play and read actions', (
    tester,
  ) async {
    var readTapped = false;
    var playTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              BookPreviewOverlay(
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
                position: const Offset(200, 100),
                showPlay: true,
                onPlay: () => playTapped = true,
                onRead: () => readTapped = true,
                onDismiss: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Continue · Page 7'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(readTapped, isTrue);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(playTapped, isTrue);
  });

  testWidgets('hides play action when narration unavailable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              BookPreviewOverlay(
                book: const Book(
                  id: 'book-2',
                  title: 'Quiet Book',
                  pageCount: 12,
                  pages: [],
                ),
                position: const Offset(200, 100),
                showPlay: false,
                onPlay: null,
                onRead: () {},
                onDismiss: () {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    expect(find.text('New'), findsOneWidget);
  });
}
