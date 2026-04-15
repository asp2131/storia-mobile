import 'package:flutter/foundation.dart';

import '../../../data/models.dart';
import 'book_progress.dart';

@immutable
class ContinueReadingItem {
  const ContinueReadingItem({
    required this.book,
    required this.progress,
    required this.hasNarration,
  });

  final Book book;
  final BookProgress progress;
  final bool hasNarration;

  factory ContinueReadingItem.fromJson(Map<String, dynamic> json) {
    final bookJson = json['book'] as Map<String, dynamic>? ?? {};
    final progressJson = json['progress'] as Map<String, dynamic>? ?? {};

    return ContinueReadingItem(
      book: Book.fromLibraryJson(bookJson),
      progress: BookProgress.fromJson(progressJson),
      hasNarration: bookJson['hasNarration'] as bool? ??
          bookJson['has_narration'] as bool? ??
          false,
    );
  }
}
