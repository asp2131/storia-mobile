import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Storia_Kids/src/features/reader/presentation/widgets/completion_handoff_sheet.dart';

Future<void> _pumpSheet(
  WidgetTester tester, {
  bool hasQuestions = true,
  String bookTitle = 'Moon Stories',
  String? childName,
  int? pagesRead,
  int? readingDurationMinutes,
  VoidCallback? onPlayAgain,
  VoidCallback? onReadAgain,
  VoidCallback? onQuickQuestions,
  VoidCallback? onBackToLibrary,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CompletionHandoffSheet(
          bookTitle: bookTitle,
          hasQuestions: hasQuestions,
          childName: childName,
          pagesRead: pagesRead,
          readingDurationMinutes: readingDurationMinutes,
          onPlayAgain: onPlayAgain ?? () {},
          onReadAgain: onReadAgain ?? () {},
          onQuickQuestions: onQuickQuestions ?? () {},
          onBackToLibrary: onBackToLibrary ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders all 4 actions when hasQuestions is true', (tester) async {
    await _pumpSheet(tester, hasQuestions: true);

    expect(find.text('Quick questions'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Read again'), findsOneWidget);
    expect(find.text('Back to library'), findsOneWidget);
  });

  testWidgets('hides Quick questions when hasQuestions is false', (tester) async {
    await _pumpSheet(tester, hasQuestions: false);

    expect(find.text('Quick questions'), findsNothing);
    expect(find.text('Play again'), findsOneWidget);
    expect(find.text('Read again'), findsOneWidget);
    expect(find.text('Back to library'), findsOneWidget);
  });

  testWidgets('shows personalized title when childName provided', (tester) async {
    await _pumpSheet(tester, childName: 'Luna');

    expect(find.text('Great job, Luna!'), findsOneWidget);
    expect(find.text('Great job finishing the story!'), findsNothing);
  });

  testWidgets('shows generic title when childName is null', (tester) async {
    await _pumpSheet(tester);

    expect(find.text('Great job finishing the story!'), findsOneWidget);
  });

  testWidgets('shows generic title when childName is empty string', (tester) async {
    await _pumpSheet(tester, childName: '   ');

    expect(find.text('Great job finishing the story!'), findsOneWidget);
  });

  testWidgets('shows session summary when pages and minutes provided', (tester) async {
    await _pumpSheet(
      tester,
      pagesRead: 12,
      readingDurationMinutes: 8,
    );

    expect(find.text('You read 12 pages in 8 minutes'), findsOneWidget);
  });

  testWidgets('summary handles singular pluralization', (tester) async {
    await _pumpSheet(
      tester,
      pagesRead: 1,
      readingDurationMinutes: 1,
    );

    expect(find.text('You read 1 page in 1 minute'), findsOneWidget);
  });

  testWidgets('summary hidden when both data missing', (tester) async {
    await _pumpSheet(tester);

    expect(find.textContaining('You read'), findsNothing);
  });

  testWidgets('summary shows only pages when minutes missing', (tester) async {
    await _pumpSheet(tester, pagesRead: 5);

    expect(find.text('You read 5 pages'), findsOneWidget);
  });

  testWidgets('action callbacks fire on tap', (tester) async {
    var quick = false, play = false, read = false, back = false;

    await _pumpSheet(
      tester,
      onQuickQuestions: () => quick = true,
      onPlayAgain: () => play = true,
      onReadAgain: () => read = true,
      onBackToLibrary: () => back = true,
    );

    await tester.tap(find.text('Quick questions'));
    await tester.pump();
    expect(quick, isTrue);

    await tester.tap(find.text('Play again'));
    await tester.pump();
    expect(play, isTrue);

    await tester.tap(find.text('Read again'));
    await tester.pump();
    expect(read, isTrue);

    await tester.tap(find.text('Back to library'));
    await tester.pump();
    expect(back, isTrue);
  });
}
