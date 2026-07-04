import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/reader/celebration/book_celebration_screen.dart';
import 'package:loratone/src/features/reader/celebration/book_celebration_summary.dart';

// disableAnimations => reduced-motion path: Lottie/confetti/sunburst tickers
// stay idle, so the tree settles deterministically in tests.
Widget _wrap(BookCelebrationSummary summary) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: BookCelebrationScreen(summary: summary),
    ),
  ),
);

const _summary = BookCelebrationSummary(
  bookTitle: 'The Brave Little Fox',
  coverUrl: null,
  pagesRead: 12,
  timeRead: Duration(minutes: 8),
);

void main() {
  testWidgets('renders headline, book, stats and the single CTA', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_summary));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('You finished!'), findsOneWidget);
    expect(find.text('The Brave Little Fox'), findsOneWidget);
    expect(find.text('12'), findsOneWidget); // pages
    expect(find.text('pages'), findsOneWidget);
    expect(find.text('8'), findsOneWidget); // minutes
    expect(find.text('min read'), findsOneWidget);
    expect(find.text('Back to Library'), findsOneWidget);
  });

  testWidgets('omits the sparks tile in v1 (sparks off)', (tester) async {
    await tester.pumpWidget(_wrap(_summary));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('sparks'), findsNothing);
  });
}
