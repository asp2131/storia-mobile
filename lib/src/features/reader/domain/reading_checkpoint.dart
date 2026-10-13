import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Ownership is independent of sample/catalog reader capabilities.
class ReadingOwner {
  const ReadingOwner.guest() : userId = null, childId = null;

  const ReadingOwner.child({
    required String this.userId,
    required String this.childId,
  });

  final String? userId;
  final String? childId;

  bool get isGuest => userId == null;

  // Const construction cannot perform trim-based validation. Validate at use
  // boundaries before constructing a storage scope or querying any records.
  void validate() {
    if (!isGuest) {
      _requireNonBlank(userId!, 'userId');
      _requireNonBlank(childId!, 'childId');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingOwner &&
      userId == other.userId &&
      childId == other.childId;

  @override
  int get hashCode => Object.hash(userId, childId);
}

enum CheckpointClaimResult { saved, alreadySaved, existingProgress }

/// A page-level bookmark, not an audio offset or a server progress record.
class ReadingCheckpoint {
  const ReadingCheckpoint({
    required this.bookId,
    required this.contentRevision,
    required this.pageId,
    required this.pageIndex,
    required this.completed,
    required this.updatedAt,
    this.savedNextBookId,
  });

  static const schemaVersion = 1;

  final String bookId;
  final String contentRevision;
  final String pageId;
  final int pageIndex;
  final bool completed;
  final DateTime updatedAt;
  final String? savedNextBookId;

  void validate() {
    _requireNonBlank(bookId, 'bookId');
    _requireNonBlank(contentRevision, 'contentRevision');
    _requireNonBlank(pageId, 'pageId');
    if (pageIndex < 0) {
      throw ArgumentError('pageIndex must not be negative.', 'pageIndex');
    }
    if (savedNextBookId != null) {
      _requireNonBlank(savedNextBookId!, 'savedNextBookId');
    }
  }

  factory ReadingCheckpoint.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final bookId = json['bookId'];
    final revision = json['contentRevision'];
    final pageId = json['pageId'];
    final pageIndex = json['pageIndex'];
    final completed = json['completed'];
    final updatedAt = json['updatedAt'];
    final savedNext = json['savedNextBookId'];
    if (version is! int ||
        version != schemaVersion ||
        bookId is! String ||
        revision is! String ||
        pageId is! String ||
        pageIndex is! int ||
        completed is! bool ||
        updatedAt is! String ||
        (savedNext != null && savedNext is! String)) {
      throw const FormatException('Invalid or unsupported reading checkpoint.');
    }
    final timestamp = DateTime.tryParse(updatedAt);
    if (timestamp == null) {
      throw const FormatException('Invalid reading checkpoint update time.');
    }
    final checkpoint = ReadingCheckpoint(
      bookId: bookId,
      contentRevision: revision,
      pageId: pageId,
      pageIndex: pageIndex,
      completed: completed,
      updatedAt: timestamp.toUtc(),
      savedNextBookId: savedNext as String?,
    );
    try {
      checkpoint.validate();
    } on ArgumentError {
      throw const FormatException('Invalid reading checkpoint values.');
    }
    return checkpoint;
  }

  Map<String, dynamic> toJson() {
    validate();
    return {
      'version': schemaVersion,
      'bookId': bookId,
      'contentRevision': contentRevision,
      'pageId': pageId,
      'pageIndex': pageIndex,
      'completed': completed,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (savedNextBookId != null) 'savedNextBookId': savedNextBookId,
    };
  }
}

/// Resolve only after real content has loaded. An unavailable book must leave
/// its persisted checkpoint untouched, rather than inventing a page zero.
ReadingCheckpoint resolveReadingCheckpoint({
  required ReadingCheckpoint checkpoint,
  required String contentRevision,
  required List<String> pageIds,
}) {
  checkpoint.validate();
  _requireNonBlank(contentRevision, 'contentRevision');
  if (pageIds.isEmpty) {
    throw ArgumentError('Cannot restore a book without pages.', 'pageIds');
  }
  for (final pageId in pageIds) {
    _requireNonBlank(pageId, 'pageIds');
  }
  final matchingIndex = pageIds.indexOf(checkpoint.pageId);
  final resolvedIndex = matchingIndex >= 0
      ? matchingIndex
      : checkpoint.pageIndex.clamp(0, pageIds.length - 1).toInt();

  // A bookmark does not contain the previous page structure, so it cannot
  // prove that changed content has already been read to completion.
  final completionRemainsValid =
      checkpoint.contentRevision == contentRevision &&
      matchingIndex == pageIds.length - 1;
  return ReadingCheckpoint(
    bookId: checkpoint.bookId,
    contentRevision: contentRevision,
    pageId: pageIds[resolvedIndex],
    pageIndex: resolvedIndex,
    completed: checkpoint.completed && completionRemainsValid,
    updatedAt: checkpoint.updatedAt,
    savedNextBookId: checkpoint.savedNextBookId,
  );
}

/// A structural fingerprint only; this is not server publication versioning.
/// JSON preserves order and boundaries, unlike concatenating page IDs.
String catalogContentRevision(Iterable<String> pageIds) {
  final orderedIds = pageIds.toList(growable: false);
  for (final pageId in orderedIds) {
    _requireNonBlank(pageId, 'pageIds');
  }
  return sha256.convert(utf8.encode(jsonEncode(orderedIds))).toString();
}

void _requireNonBlank(String value, String field) {
  if (value.trim().isEmpty) {
    throw ArgumentError('$field must not be blank.', field);
  }
}
