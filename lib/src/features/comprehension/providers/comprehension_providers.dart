import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../data/comprehension_repository.dart';
import '../domain/book_question.dart';
import '../domain/comprehension_result.dart';

final comprehensionRepositoryProvider =
    Provider<ComprehensionRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ComprehensionRepository(supabase);
});

final bookQuestionsProvider =
    FutureProvider.family<List<BookQuestion>, String>((ref, bookId) async {
  final repo = ref.watch(comprehensionRepositoryProvider);
  return repo.fetchBookQuestions(bookId);
});

enum ComprehensionFlowStatus { idle, answering, submitting, done }

class ComprehensionFlowState {
  const ComprehensionFlowState({
    this.questions = const [],
    this.currentIndex = 0,
    this.answers = const [],
    this.status = ComprehensionFlowStatus.idle,
    this.result,
  });

  final List<BookQuestion> questions;
  final int currentIndex;
  final List<QuestionAnswer> answers;
  final ComprehensionFlowStatus status;
  final ComprehensionResult? result;

  int get totalQuestions => questions.length;
  bool get isLastQuestion => currentIndex >= totalQuestions - 1;
  BookQuestion? get currentQuestion =>
      currentIndex < questions.length ? questions[currentIndex] : null;

  ComprehensionFlowState copyWith({
    List<BookQuestion>? questions,
    int? currentIndex,
    List<QuestionAnswer>? answers,
    ComprehensionFlowStatus? status,
    ComprehensionResult? result,
  }) {
    return ComprehensionFlowState(
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      status: status ?? this.status,
      result: result ?? this.result,
    );
  }
}

class ComprehensionFlowNotifier extends StateNotifier<ComprehensionFlowState> {
  ComprehensionFlowNotifier(this._repository) : super(const ComprehensionFlowState());

  final ComprehensionRepository _repository;

  void start(List<BookQuestion> questions) {
    state = ComprehensionFlowState(
      questions: questions,
      status: ComprehensionFlowStatus.answering,
    );
  }

  void answerQuestion(String questionId, String selectedAnswer) {
    final answer = QuestionAnswer(
      questionId: questionId,
      selectedAnswer: selectedAnswer,
    );

    final updatedAnswers = [...state.answers, answer];

    if (state.isLastQuestion) {
      state = state.copyWith(answers: updatedAnswers);
    } else {
      state = state.copyWith(
        answers: updatedAnswers,
        currentIndex: state.currentIndex + 1,
      );
    }
  }

  Future<ComprehensionResult?> submit({
    required String childProfileId,
    required String bookId,
    String? readingSessionId,
  }) async {
    state = state.copyWith(status: ComprehensionFlowStatus.submitting);

    final result = await _repository.submitAnswers(
      childProfileId: childProfileId,
      bookId: bookId,
      readingSessionId: readingSessionId,
      answers: state.answers,
    );

    state = state.copyWith(
      status: ComprehensionFlowStatus.done,
      result: result,
    );

    return result;
  }

  void reset() {
    state = const ComprehensionFlowState();
  }
}

final comprehensionFlowProvider = StateNotifierProvider.autoDispose<
    ComprehensionFlowNotifier, ComprehensionFlowState>((ref) {
  final repo = ref.watch(comprehensionRepositoryProvider);
  return ComprehensionFlowNotifier(repo);
});
