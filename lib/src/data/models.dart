import 'package:flutter/foundation.dart';

class WordTimestamp {
  final String word;
  final double start;
  final double end;

  const WordTimestamp({
    required this.word,
    required this.start,
    required this.end,
  });

  factory WordTimestamp.fromJson(Map<String, dynamic> json) {
    return WordTimestamp(
      word: json['word'] as String? ?? '',
      start: (json['start'] as num?)?.toDouble() ?? 0,
      end: (json['end'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TextElement {
  final String id;
  final String text;
  final double x;
  final double y;
  final double width;
  final String fontFamily;
  final double fontSize;
  final int fontWeight;
  final String color;
  final String textAlign;
  final double rotation;
  final TextShadow? shadow;
  final TextBackground? background;

  const TextElement({
    required this.id,
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.fontFamily,
    required this.fontSize,
    required this.fontWeight,
    required this.color,
    required this.textAlign,
    required this.rotation,
    this.shadow,
    this.background,
  });

  factory TextElement.fromJson(Map<String, dynamic> json) {
    return TextElement(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 0,
      fontFamily: json['fontFamily'] as String? ?? 'Inter',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 0,
      fontWeight: (json['fontWeight'] as num?)?.toInt() ?? 400,
      color: json['color'] as String? ?? '#FFFFFF',
      textAlign: json['textAlign'] as String? ?? 'left',
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
      shadow: json['shadow'] is Map<String, dynamic>
          ? TextShadow.fromJson(json['shadow'] as Map<String, dynamic>)
          : null,
      background: json['background'] is Map<String, dynamic>
          ? TextBackground.fromJson(json['background'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TextShadow {
  final String color;
  final double blur;
  final double x;
  final double y;

  const TextShadow({
    required this.color,
    required this.blur,
    required this.x,
    required this.y,
  });

  factory TextShadow.fromJson(Map<String, dynamic> json) {
    return TextShadow(
      color: json['color'] as String? ?? '#000000',
      blur: (json['blur'] as num?)?.toDouble() ?? 0,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TextBackground {
  final String color;
  final double? padding;
  final double? borderRadius;

  const TextBackground({required this.color, this.padding, this.borderRadius});

  factory TextBackground.fromJson(Map<String, dynamic> json) {
    return TextBackground(
      color: json['color'] as String? ?? '#000000',
      padding: (json['padding'] as num?)?.toDouble(),
      borderRadius: (json['borderRadius'] as num?)?.toDouble(),
    );
  }
}

class TextOverlayConfig {
  final int version;
  final List<TextElement> elements;

  const TextOverlayConfig({required this.version, required this.elements});

  factory TextOverlayConfig.fromJson(Map<String, dynamic> json) {
    final elements = (json['elements'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TextElement.fromJson)
        .toList();

    return TextOverlayConfig(
      version: (json['version'] as num?)?.toInt() ?? 1,
      elements: elements,
    );
  }
}

class PageData {
  final String id;
  final int pageNumber;
  final String? textContent;
  final TextOverlayConfig? overlay;
  final String? imageUrl;
  final String? narrationUrl;
  final String? soundscapeUrl;
  final String? compositedImageUrl;
  final List<WordTimestamp>? narrationTimestamps;

  const PageData({
    required this.id,
    required this.pageNumber,
    this.textContent,
    this.overlay,
    this.imageUrl,
    this.narrationUrl,
    this.soundscapeUrl,
    this.compositedImageUrl,
    this.narrationTimestamps,
  });

  PageData copyWith({String? soundscapeUrl}) {
    return PageData(
      id: id,
      pageNumber: pageNumber,
      textContent: textContent,
      overlay: overlay,
      imageUrl: imageUrl,
      narrationUrl: narrationUrl,
      soundscapeUrl: soundscapeUrl ?? this.soundscapeUrl,
      compositedImageUrl: compositedImageUrl,
      narrationTimestamps: narrationTimestamps,
    );
  }

  factory PageData.fromJson(Map<String, dynamic> json) {
    final rawTimestamps =
        json['narration_timestamps'] ?? json['narrationTimestamps'];
    final timestamps = rawTimestamps is List
        ? rawTimestamps
              .whereType<Map<String, dynamic>>()
              .map(WordTimestamp.fromJson)
              .toList()
        : null;

    final overlayJson = json['text_overlay'];

    // --- Soundscape URL ---
    // Primary: page_audio_assignments where audio_type == 'soundscape' (matches RN).
    // Fallback: scenes -> soundscapes relation (via page's scene_id FK).
    String? soundscapeUrl;

    final assignments = json['page_audio_assignments'];
    if (assignments is List) {
      for (final a in assignments.whereType<Map<String, dynamic>>()) {
        if (a['audio_type'] == 'soundscape') {
          final url = a['audio_url'] as String?;
          if (url != null && url.isNotEmpty) {
            soundscapeUrl = url;
            break;
          }
        }
      }
    }

    // Fallback to scenes -> soundscapes if no assignment found.
    if (soundscapeUrl == null) {
      final scenesData = json['scenes'];
      if (scenesData is Map<String, dynamic>) {
        final rawSoundscapes = scenesData['soundscapes'];
        if (rawSoundscapes is List && rawSoundscapes.isNotEmpty) {
          final soundscapes = rawSoundscapes
              .whereType<Map<String, dynamic>>()
              .toList();
          final approved = soundscapes
              .where((s) => s['admin_approved'] == true)
              .toList();
          final chosen = approved.isNotEmpty
              ? approved.first
              : soundscapes.first;
          soundscapeUrl = chosen['audio_url'] as String?;
        }
      }
    }

    return PageData(
      id: json['id']?.toString() ?? '',
      pageNumber: _parsePageNumber(json),
      textContent:
          json['text_content'] as String? ?? json['textContent'] as String?,
      overlay: overlayJson is Map<String, dynamic>
          ? TextOverlayConfig.fromJson(overlayJson)
          : null,
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
      narrationUrl:
          json['narration_url'] as String? ?? json['narrationUrl'] as String?,
      soundscapeUrl: soundscapeUrl,
      compositedImageUrl:
          json['composited_image_url'] as String? ??
          json['compositedImageUrl'] as String?,
      narrationTimestamps: timestamps,
    );
  }
}

class Book {
  final String id;
  final String title;
  final String? author;
  final String? coverUrl;
  final int pageCount;
  final List<PageData> pages;
  final bool hasQuestions;

  const Book({
    required this.id,
    required this.title,
    this.author,
    this.coverUrl,
    required this.pageCount,
    required this.pages,
    this.hasQuestions = false,
  });

  factory Book.fromLibraryJson(Map<String, dynamic> json) {
    final pageCount = _parseBookPageCount(json);
    return Book(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String?,
      coverUrl: json['cover_url'] as String? ?? json['coverUrl'] as String?,
      pageCount: pageCount,
      pages: const [],
      hasQuestions: json['hasQuestions'] as bool? ??
          json['has_questions'] as bool? ??
          false,
    );
  }

  factory Book.fromJson(Map<String, dynamic> json) {
    final rawPages = (json['pages'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    final parsedPages = rawPages
        .whereType<Map<String, dynamic>>()
        .map(PageData.fromJson)
        .toList();

    final pages = _sortedPages(parsedPages);
    final soundscapeAssignments = _extractSoundscapeAssignments(rawPages);
    final pagesWithResolvedSoundscapes = _applyResolvedSoundscapes(
      pages,
      soundscapeAssignments,
    );
    assert(() {
      if (_isDifferentOrder(parsedPages, pages)) {
        debugPrint(
          '[Book.fromJson] Incoming page order was unsorted for book '
          '${json['id'] ?? ''}. Applying deterministic sort by pageNumber/id.',
        );
      }
      return true;
    }());

    return Book(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String?,
      coverUrl: json['cover_url'] as String? ?? json['coverUrl'] as String?,
      pageCount: pagesWithResolvedSoundscapes.length,
      pages: pagesWithResolvedSoundscapes,
      hasQuestions: json['hasQuestions'] as bool? ??
          json['has_questions'] as bool? ??
          false,
    );
  }
}

int _parseBookPageCount(Map<String, dynamic> json) {
  final directCount = _parseNonNegativeInt(
    json['page_count'] ?? json['pageCount'],
  );
  if (directCount != null) {
    return directCount;
  }

  final pagesValue = json['pages'];
  if (pagesValue is List) {
    if (pagesValue.isEmpty) {
      return 0;
    }

    final first = pagesValue.first;
    if (first is Map<String, dynamic>) {
      final embeddedCount = _parseNonNegativeInt(first['count']);
      if (embeddedCount != null) {
        return embeddedCount;
      }
    }

    return pagesValue.length;
  }

  return 0;
}

int? _parseNonNegativeInt(dynamic value) {
  if (value is num) {
    final intValue = value.toInt();
    return intValue >= 0 ? intValue : null;
  }
  if (value is String) {
    final intValue = int.tryParse(value);
    if (intValue == null || intValue < 0) {
      return null;
    }
    return intValue;
  }
  return null;
}

class _SoundscapeAssignment {
  final int id;
  final String audioUrl;
  final int rangeStart;
  final int rangeEnd;

  const _SoundscapeAssignment({
    required this.id,
    required this.audioUrl,
    required this.rangeStart,
    required this.rangeEnd,
  });
}

const int _invalidPageNumber = 1 << 30;

int _parsePageNumber(Map<String, dynamic> json) {
  final rawPageNumber = json['page_number'] ?? json['pageNumber'];
  if (rawPageNumber is num) {
    final pageNumber = rawPageNumber.toInt();
    return pageNumber > 0 ? pageNumber : _invalidPageNumber;
  }
  if (rawPageNumber is String) {
    final pageNumber = int.tryParse(rawPageNumber);
    if (pageNumber == null || pageNumber <= 0) {
      return _invalidPageNumber;
    }
    return pageNumber;
  }
  return _invalidPageNumber;
}

List<PageData> _sortedPages(List<PageData> pages) {
  final indexedPages = pages.asMap().entries.toList();
  indexedPages.sort((a, b) {
    final pageNumberCompare = a.value.pageNumber.compareTo(b.value.pageNumber);
    if (pageNumberCompare != 0) {
      return pageNumberCompare;
    }

    final idCompare = a.value.id.compareTo(b.value.id);
    if (idCompare != 0) {
      return idCompare;
    }

    return a.key.compareTo(b.key);
  });

  return indexedPages.map((entry) => entry.value).toList(growable: false);
}

bool _isDifferentOrder(List<PageData> original, List<PageData> sorted) {
  if (identical(original, sorted)) {
    return false;
  }
  if (original.length != sorted.length) {
    return true;
  }
  for (var i = 0; i < original.length; i++) {
    if (!identical(original[i], sorted[i])) {
      return true;
    }
  }
  return false;
}

List<_SoundscapeAssignment> _extractSoundscapeAssignments(
  List<Map<String, dynamic>> rawPages,
) {
  final assignments = <_SoundscapeAssignment>[];

  for (final rawPage in rawPages) {
    final rawAssignments = rawPage['page_audio_assignments'];
    if (rawAssignments is! List) {
      continue;
    }

    final sourcePageNumber = _parsePageNumber(rawPage);
    for (final rawAssignment
        in rawAssignments.whereType<Map<String, dynamic>>()) {
      if (rawAssignment['audio_type'] != 'soundscape') {
        continue;
      }

      final audioUrl = rawAssignment['audio_url'] as String?;
      if (audioUrl == null || audioUrl.isEmpty) {
        continue;
      }

      final assignmentId = _parseOptionalPositiveInt(rawAssignment['id']) ?? 0;
      final scope =
          (rawAssignment['scope'] as String?)?.toLowerCase() ?? 'single';
      final start =
          _parseOptionalPositiveInt(rawAssignment['range_start']) ??
          _parseOptionalPositiveInt(rawAssignment['rangeStart']);
      final end =
          _parseOptionalPositiveInt(rawAssignment['range_end']) ??
          _parseOptionalPositiveInt(rawAssignment['rangeEnd']);

      final effectiveStart = scope == 'range'
          ? (start ?? sourcePageNumber)
          : sourcePageNumber;
      final effectiveEnd = scope == 'range'
          ? (end ?? effectiveStart)
          : effectiveStart;
      if (effectiveStart <= 0 || effectiveStart >= _invalidPageNumber) {
        continue;
      }

      final normalizedStart = effectiveStart < effectiveEnd
          ? effectiveStart
          : effectiveEnd;
      final normalizedEnd = effectiveStart > effectiveEnd
          ? effectiveStart
          : effectiveEnd;

      assignments.add(
        _SoundscapeAssignment(
          id: assignmentId,
          audioUrl: audioUrl,
          rangeStart: normalizedStart,
          rangeEnd: normalizedEnd,
        ),
      );
    }
  }

  return assignments;
}

List<PageData> _applyResolvedSoundscapes(
  List<PageData> pages,
  List<_SoundscapeAssignment> assignments,
) {
  if (assignments.isEmpty) {
    return pages;
  }

  return pages
      .map((page) {
        final resolvedUrl = _resolveRangeSoundscapeForPage(
          page.pageNumber,
          assignments,
        );
        if (resolvedUrl == null || resolvedUrl == page.soundscapeUrl) {
          return page;
        }
        return page.copyWith(soundscapeUrl: resolvedUrl);
      })
      .toList(growable: false);
}

String? _resolveRangeSoundscapeForPage(
  int pageNumber,
  List<_SoundscapeAssignment> assignments,
) {
  _SoundscapeAssignment? best;
  for (final assignment in assignments) {
    if (pageNumber < assignment.rangeStart ||
        pageNumber > assignment.rangeEnd) {
      continue;
    }

    if (best == null) {
      best = assignment;
      continue;
    }

    if (assignment.id > best.id) {
      best = assignment;
    }
  }

  return best?.audioUrl;
}

int? _parseOptionalPositiveInt(dynamic value) {
  if (value is num) {
    final intValue = value.toInt();
    return intValue > 0 ? intValue : null;
  }
  if (value is String) {
    final intValue = int.tryParse(value);
    if (intValue == null || intValue <= 0) {
      return null;
    }
    return intValue;
  }
  return null;
}
