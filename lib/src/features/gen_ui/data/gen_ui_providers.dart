import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gen_ui_activity.dart';
import '../domain/gen_ui_card_schema.dart';
import '../domain/gen_ui_prompt_policy.dart';
import 'gen_ui_activity_controller.dart';
import 'mock_gen_ui_cards.dart';

final genUiActivityControllerProvider =
    StateNotifierProvider<GenUiActivityController, GenUiActivityLog>((ref) {
      return GenUiActivityController();
    });

final mockGenUiCardRepositoryProvider = Provider<MockGenUiCardRepository>((ref) {
  return const MockGenUiCardRepository();
});

final genUiPromptPolicyProvider = Provider<GenUiPromptPolicy>((ref) {
  return GenUiPromptPolicy();
});

final readerGenUiCardProvider =
    Provider.family<GenUiCardSchema?, ReaderGenUiPromptRequest>((ref, request) {
      final log = ref.watch(genUiActivityControllerProvider);
      final repository = ref.watch(mockGenUiCardRepositoryProvider);
      final policy = ref.watch(genUiPromptPolicyProvider);
      final candidates = repository.readerCardsForPage(
        bookId: request.bookId,
        pageIndex: request.pageIndex,
      );
      return policy.chooseCard(
        candidates: candidates,
        log: log,
        pageIndex: request.pageIndex,
      );
    });

class ReaderGenUiPromptRequest {
  const ReaderGenUiPromptRequest({required this.bookId, required this.pageIndex});

  final String bookId;
  final int pageIndex;

  @override
  bool operator ==(Object other) {
    return other is ReaderGenUiPromptRequest &&
        other.bookId == bookId &&
        other.pageIndex == pageIndex;
  }

  @override
  int get hashCode => Object.hash(bookId, pageIndex);
}
