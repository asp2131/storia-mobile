import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Storia_Kids/src/features/comprehension/domain/comprehension_result.dart';
import 'package:Storia_Kids/src/features/comprehension/presentation/widgets/comprehension_result_card.dart';

Future<void> _pumpResult(
  WidgetTester tester, {
  required ComprehensionResult result,
  VoidCallback? onBack,
  VoidCallback? onReadAgain,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ComprehensionResultCard(
          result: result,
          onBackToLibrary: onBack ?? () {},
          onReadAgain: onReadAgain ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders score summary', (tester) async {
    await _pumpResult(
      tester,
      result: const ComprehensionResult(
        bookId: 'b1',
        childProfileId: 'c1',
        totalQuestions: 3,
        correctCount: 2,
        scorePercent: 67,
      ),
    );

    expect(find.text('You got 2 out of 3!'), findsOneWidget);
  });

  testWidgets('shows Amazing! for perfect score', (tester) async {
    await _pumpResult(
      tester,
      result: const ComprehensionResult(
        bookId: 'b1',
        childProfileId: 'c1',
        totalQuestions: 3,
        correctCount: 3,
        scorePercent: 100,
      ),
    );

    expect(find.text('Amazing!'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('shows Nice work! for partial score', (tester) async {
    await _pumpResult(
      tester,
      result: const ComprehensionResult(
        bookId: 'b1',
        childProfileId: 'c1',
        totalQuestions: 3,
        correctCount: 1,
        scorePercent: 33,
      ),
    );

    expect(find.text('Nice work!'), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_rounded), findsOneWidget);
  });

  testWidgets('buttons invoke correct callbacks', (tester) async {
    var back = false;
    var read = false;

    await _pumpResult(
      tester,
      result: const ComprehensionResult(
        bookId: 'b1',
        childProfileId: 'c1',
        totalQuestions: 2,
        correctCount: 1,
        scorePercent: 50,
      ),
      onBack: () => back = true,
      onReadAgain: () => read = true,
    );

    await tester.tap(find.text('Back to library'));
    await tester.pump();
    expect(back, isTrue);

    await tester.tap(find.text('Read another book'));
    await tester.pump();
    expect(read, isTrue);
  });
}
