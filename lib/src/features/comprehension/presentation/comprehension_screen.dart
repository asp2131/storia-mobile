import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/storia_colors.dart';
import '../../child/providers/active_child_provider.dart';
import '../../reader/providers/reading_session_coordinator_provider.dart';
import '../providers/comprehension_providers.dart';
import 'widgets/comprehension_result_card.dart';
import 'widgets/question_card.dart';

class ComprehensionScreen extends ConsumerStatefulWidget {
  const ComprehensionScreen({
    super.key,
    required this.bookId,
    this.sessionId,
  });

  final String bookId;
  final String? sessionId;

  @override
  ConsumerState<ComprehensionScreen> createState() =>
      _ComprehensionScreenState();
}

class _ComprehensionScreenState extends ConsumerState<ComprehensionScreen> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(bookQuestionsProvider(widget.bookId));
    final flowState = ref.watch(comprehensionFlowProvider);

    return Scaffold(
      backgroundColor: StoriaColors.paper,
      appBar: AppBar(
        backgroundColor: StoriaColors.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: StoriaColors.ink),
          onPressed: () => context.go('/library'),
        ),
        title: Text(
          'Quick Questions',
          style: GoogleFonts.quicksand(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: StoriaColors.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: questionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: StoriaColors.sage),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Could not load questions',
                style: GoogleFonts.quicksand(
                  fontSize: 16,
                  color: StoriaColors.inkMuted,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/library'),
                child: const Text('Back to library'),
              ),
            ],
          ),
        ),
        data: (questions) {
          if (questions.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.go('/library');
            });
            return const SizedBox.shrink();
          }

          if (!_initialized) {
            _initialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(comprehensionFlowProvider.notifier).start(questions);
              _trackStart(questions.length);
            });
          }

          if (flowState.status == ComprehensionFlowStatus.done &&
              flowState.result != null) {
            return ComprehensionResultCard(
              result: flowState.result!,
              onBackToLibrary: () => context.go('/library'),
              onReadAgain: () => context.go('/library'),
            );
          }

          if (flowState.status == ComprehensionFlowStatus.submitting) {
            return const Center(
              child: CircularProgressIndicator(color: StoriaColors.sage),
            );
          }

          final question = flowState.currentQuestion;
          if (question == null) return const SizedBox.shrink();

          return QuestionCard(
            key: ValueKey(question.id),
            question: question,
            questionNumber: flowState.currentIndex + 1,
            totalQuestions: flowState.totalQuestions,
            onAnswerSelected: (optionKey) =>
                _onAnswerSelected(optionKey, question.id),
          );
        },
      ),
    );
  }

  void _onAnswerSelected(String optionKey, String questionId) {
    final notifier = ref.read(comprehensionFlowProvider.notifier);
    final state = ref.read(comprehensionFlowProvider);

    notifier.answerQuestion(questionId, optionKey);

    final analytics = ref.read(analyticsServiceProvider);
    final childId = ref.read(activeChildProvider).value?.id ?? '';
    analytics.trackComprehensionQuestionAnswered(
      childId: childId,
      bookId: widget.bookId,
      questionId: questionId,
      isCorrect: false, // correctness determined server-side
    );

    if (state.isLastQuestion) {
      _submitAnswers();
    }
  }

  Future<void> _submitAnswers() async {
    final childId = ref.read(activeChildProvider).value?.id ?? '';
    final notifier = ref.read(comprehensionFlowProvider.notifier);

    final result = await notifier.submit(
      childProfileId: childId,
      bookId: widget.bookId,
      readingSessionId: widget.sessionId,
    );

    if (result != null) {
      final analytics = ref.read(analyticsServiceProvider);
      analytics.trackComprehensionCompleted(
        childId: childId,
        bookId: widget.bookId,
        sessionId: widget.sessionId ?? '',
        correctCount: result.correctCount,
        totalQuestions: result.totalQuestions,
        scorePercent: result.scorePercent,
      );
    }
  }

  void _trackStart(int totalQuestions) {
    final analytics = ref.read(analyticsServiceProvider);
    final childId = ref.read(activeChildProvider).value?.id ?? '';
    analytics.trackComprehensionStarted(
      childId: childId,
      bookId: widget.bookId,
      sessionId: widget.sessionId ?? '',
      totalQuestions: totalQuestions,
    );
  }
}
