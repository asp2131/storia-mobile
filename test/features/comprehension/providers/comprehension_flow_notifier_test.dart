import 'package:flutter_test/flutter_test.dart';
import 'package:Storia_Kids/src/features/comprehension/data/comprehension_repository.dart';
import 'package:Storia_Kids/src/features/comprehension/domain/book_question.dart';
import 'package:Storia_Kids/src/features/comprehension/domain/comprehension_result.dart';
import 'package:Storia_Kids/src/features/comprehension/providers/comprehension_providers.dart';

class _FakeRepository implements ComprehensionRepository {
  _FakeRepository({this.result});

  final ComprehensionResult? result;
  List<QuestionAnswer>? capturedAnswers;
  String? capturedChildId;
  String? capturedBookId;
  String? capturedSessionId;

  @override
  Future<List<BookQuestion>> fetchBookQuestions(String bookId) async {
    return const [];
  }

  @override
  Future<ComprehensionResult?> submitAnswers({
    required String childProfileId,
    required String bookId,
    String? readingSessionId,
    required List<QuestionAnswer> answers,
  }) async {
    capturedChildId = childProfileId;
    capturedBookId = bookId;
    capturedSessionId = readingSessionId;
    capturedAnswers = List.of(answers);
    return result;
  }
}

BookQuestion _question(String id, {String text = 'Q?'}) {
  return BookQuestion(
    id: id,
    bookId: 'b1',
    questionText: text,
    questionType: 'multiple_choice',
    sortOrder: 0,
    options: const [
      BookQuestionOption(
        id: 'o1',
        optionKey: 'A',
        optionText: 'Alpha',
        sortOrder: 0,
      ),
      BookQuestionOption(
        id: 'o2',
        optionKey: 'B',
        optionText: 'Beta',
        sortOrder: 1,
      ),
    ],
  );
}

void main() {
  group('ComprehensionFlowNotifier', () {
    test('start populates questions and sets answering status', () {
      final notifier = ComprehensionFlowNotifier(_FakeRepository());
      final questions = [_question('q1'), _question('q2')];

      notifier.start(questions);

      expect(notifier.state.questions, questions);
      expect(notifier.state.currentIndex, 0);
      expect(notifier.state.answers, isEmpty);
      expect(notifier.state.status, ComprehensionFlowStatus.answering);
      expect(notifier.state.totalQuestions, 2);
      expect(notifier.state.isLastQuestion, isFalse);
      expect(notifier.state.currentQuestion?.id, 'q1');
    });

    test('answerQuestion records answer and advances index', () {
      final notifier = ComprehensionFlowNotifier(_FakeRepository());
      notifier.start([_question('q1'), _question('q2')]);

      notifier.answerQuestion('q1', 'A');

      expect(notifier.state.answers, hasLength(1));
      expect(notifier.state.answers.first.questionId, 'q1');
      expect(notifier.state.answers.first.selectedAnswer, 'A');
      expect(notifier.state.currentIndex, 1);
      expect(notifier.state.currentQuestion?.id, 'q2');
    });

    test('answerQuestion on last question does not advance past end', () {
      final notifier = ComprehensionFlowNotifier(_FakeRepository());
      notifier.start([_question('q1'), _question('q2')]);
      notifier.answerQuestion('q1', 'A');

      notifier.answerQuestion('q2', 'B');

      expect(notifier.state.answers, hasLength(2));
      expect(notifier.state.currentIndex, 1);
      expect(notifier.state.isLastQuestion, isTrue);
    });

    test('submit sets status to submitting then done with result', () async {
      final result = const ComprehensionResult(
        bookId: 'b1',
        childProfileId: 'c1',
        totalQuestions: 2,
        correctCount: 2,
        scorePercent: 100,
      );
      final repo = _FakeRepository(result: result);
      final notifier = ComprehensionFlowNotifier(repo);

      notifier.start([_question('q1'), _question('q2')]);
      notifier.answerQuestion('q1', 'A');
      notifier.answerQuestion('q2', 'B');

      final future = notifier.submit(
        childProfileId: 'c1',
        bookId: 'b1',
        readingSessionId: 'rs_1',
      );

      expect(notifier.state.status, ComprehensionFlowStatus.submitting);

      final returned = await future;

      expect(returned, same(result));
      expect(notifier.state.status, ComprehensionFlowStatus.done);
      expect(notifier.state.result, same(result));
      expect(repo.capturedChildId, 'c1');
      expect(repo.capturedBookId, 'b1');
      expect(repo.capturedSessionId, 'rs_1');
      expect(repo.capturedAnswers, hasLength(2));
    });

    test('reset clears all state', () {
      final notifier = ComprehensionFlowNotifier(_FakeRepository());
      notifier.start([_question('q1')]);
      notifier.answerQuestion('q1', 'A');

      notifier.reset();

      expect(notifier.state.questions, isEmpty);
      expect(notifier.state.answers, isEmpty);
      expect(notifier.state.currentIndex, 0);
      expect(notifier.state.status, ComprehensionFlowStatus.idle);
      expect(notifier.state.result, isNull);
    });

    test('empty questions list handles gracefully', () {
      final notifier = ComprehensionFlowNotifier(_FakeRepository());
      notifier.start(const []);

      expect(notifier.state.totalQuestions, 0);
      expect(notifier.state.currentQuestion, isNull);
      expect(notifier.state.status, ComprehensionFlowStatus.answering);
    });
  });
}
