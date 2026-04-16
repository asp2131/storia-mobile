import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Storia_Kids/src/features/comprehension/domain/book_question.dart';
import 'package:Storia_Kids/src/features/comprehension/presentation/widgets/question_card.dart';

BookQuestion _question() {
  return const BookQuestion(
    id: 'q1',
    bookId: 'b1',
    questionText: 'Where did the fox go?',
    questionType: 'multiple_choice',
    sortOrder: 0,
    options: [
      BookQuestionOption(
        id: 'o1',
        optionKey: 'A',
        optionText: 'To the forest',
        sortOrder: 0,
      ),
      BookQuestionOption(
        id: 'o2',
        optionKey: 'B',
        optionText: 'To the river',
        sortOrder: 1,
      ),
      BookQuestionOption(
        id: 'o3',
        optionKey: 'C',
        optionText: 'Home',
        sortOrder: 2,
      ),
    ],
  );
}

Future<void> _pumpQuestion(
  WidgetTester tester, {
  required void Function(String) onSelected,
  int questionNumber = 1,
  int totalQuestions = 3,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuestionCard(
          question: _question(),
          questionNumber: questionNumber,
          totalQuestions: totalQuestions,
          onAnswerSelected: onSelected,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders question text, progress, and all options', (tester) async {
    await _pumpQuestion(tester, onSelected: (_) {});

    expect(find.text('Where did the fox go?'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('To the forest'), findsOneWidget);
    expect(find.text('To the river'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
  });

  testWidgets('tapping option calls onAnswerSelected with option key', (tester) async {
    String? selected;
    await _pumpQuestion(tester, onSelected: (key) => selected = key);

    await tester.tap(find.text('To the river'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(selected, 'B');
  });

  testWidgets('subsequent taps after selection are ignored', (tester) async {
    var calls = 0;
    await _pumpQuestion(tester, onSelected: (_) => calls++);

    await tester.tap(find.text('To the forest'));
    await tester.pump();
    await tester.tap(find.text('To the river'));
    await tester.pump(const Duration(milliseconds: 700));

    expect(calls, 1);
  });

  testWidgets('semantic labels present for each option', (tester) async {
    await _pumpQuestion(tester, onSelected: (_) {});

    final labels = <String>{};
    for (final el in find.byType(Semantics).evaluate()) {
      final widget = el.widget as Semantics;
      final label = widget.properties.label;
      if (label != null) labels.add(label);
    }

    expect(labels, contains('A: To the forest'));
    expect(labels, contains('B: To the river'));
    expect(labels, contains('C: Home'));
  });
}
