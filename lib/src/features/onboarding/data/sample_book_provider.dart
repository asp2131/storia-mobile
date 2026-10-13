import 'dart:convert';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/reader_media_source.dart';
import '../../../data/models.dart';
import '../../reader/domain/reader_capabilities.dart';

/// Thrown when the bundled sample cannot be served: malformed manifest,
/// missing files, or the bundle simply not being shipped in this build.
///
/// Callers must treat this as "sample unavailable" and keep the Try-a-story
/// entry point dark — never fall back to catalog content.
class SampleContentException implements Exception {
  const SampleContentException(this.reason);

  final String reason;

  @override
  String toString() => 'SampleContentException: $reason';
}

/// A validated bundled sample: the [book] (all media as `asset:///`
/// references) plus the revision the local progress schema stores.
class SampleBookBundle {
  const SampleBookBundle({required this.book, required this.contentRevision});

  final Book book;
  final String contentRevision;
}

const String _sampleManifestAssetPath =
    'assets/onboarding/sample/manifest.json';

/// Parses and validates a decoded sample manifest.
///
/// Validation enforces the shipping contract:
/// - schemaVersion 1, [sampleBookId], non-empty contentRevision
/// - at least one page; unique, non-empty page ids; ascending page numbers
/// - every page has an illustration; all media references are bundled
///   `asset:///` paths (remote URLs are rejected outright)
/// - narrated pages carry aligned word timestamps
/// - every referenced asset path exists per [assetExists]
SampleBookBundle parseSampleManifest(
  Map<String, dynamic> manifest, {
  required bool Function(String path) assetExists,
}) {
  Never fail(String reason) => throw SampleContentException(reason);

  if (manifest['schemaVersion'] != 1) {
    fail('unsupported schemaVersion: ${manifest['schemaVersion']}');
  }
  if (manifest['bookId'] != sampleBookId) {
    fail('manifest bookId is not the reserved sample id');
  }
  final revision = (manifest['contentRevision'] ?? '').toString().trim();
  if (revision.isEmpty) {
    fail('missing contentRevision');
  }
  final title = (manifest['title'] ?? '').toString().trim();
  if (title.isEmpty) {
    fail('missing title');
  }
  final author = (manifest['author'] ?? '').toString().trim();

  String bundledAsset(String? raw, {required String what}) {
    if (raw == null || raw.toString().trim().isEmpty) {
      fail('missing $what');
    }
    final ReaderMediaSource source;
    try {
      source = ReaderMediaSource.parse(raw);
    } on ArgumentError {
      fail('$what is not a valid bundled reference');
    }
    if (source is! AssetReaderMediaSource) {
      fail('$what must be a bundled asset:/// reference, got: $raw');
    }
    return source.assetPath;
  }

  final coverPath = bundledAsset(manifest['coverUrl'], what: 'coverUrl');

  final rawPages = manifest['pages'];
  if (rawPages is! List || rawPages.isEmpty) {
    fail('sample must have at least one page');
  }

  final seenPageIds = <String>{};
  var expectedPageNumber = 1;
  final pages = <PageData>[];

  for (final rawPage in rawPages) {
    if (rawPage is! Map<String, dynamic>) {
      fail('page $expectedPageNumber is not an object');
    }
    final id = (rawPage['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      fail('page $expectedPageNumber is missing an id');
    }
    if (!seenPageIds.add(id)) {
      fail('duplicate page id: $id');
    }
    final pageNumber = rawPage['pageNumber'];
    if (pageNumber != expectedPageNumber) {
      fail('page numbers must be sequential from 1, got $pageNumber');
    }
    expectedPageNumber++;

    final imagePath = bundledAsset(
      rawPage['imageUrl'],
      what: 'page $pageNumber illustration',
    );
    if (!assetExists(imagePath)) {
      fail('missing asset file: $imagePath');
    }

    String? narrationPath;
    List<WordTimestamp>? timestamps;
    final rawNarration = rawPage['narrationUrl'];
    if (rawNarration != null && rawNarration.toString().isNotEmpty) {
      narrationPath = bundledAsset(
        rawNarration,
        what: 'page $pageNumber narration',
      );
      if (!assetExists(narrationPath)) {
        fail('missing asset file: $narrationPath');
      }
      final rawTimestamps = rawPage['narrationTimestamps'];
      if (rawTimestamps is! List || rawTimestamps.isEmpty) {
        fail('page $pageNumber has narration but no aligned word timestamps');
      }
      timestamps = <WordTimestamp>[];
      var previousEnd = 0.0;
      for (final raw in rawTimestamps) {
        if (raw is! Map<String, dynamic> ||
            raw['word'] is! String ||
            (raw['word'] as String).trim().isEmpty ||
            raw['start'] is! num ||
            raw['end'] is! num) {
          fail('page $pageNumber has malformed word timestamps');
        }
        final start = (raw['start'] as num).toDouble();
        final end = (raw['end'] as num).toDouble();
        if (!start.isFinite ||
            !end.isFinite ||
            start < previousEnd ||
            end <= start) {
          fail('page $pageNumber has invalid word timing');
        }
        timestamps.add(WordTimestamp.fromJson(raw));
        previousEnd = end;
      }
    }

    String? soundscapePath;
    final rawSoundscape = rawPage['soundscapeUrl'];
    if (rawSoundscape != null && rawSoundscape.toString().isNotEmpty) {
      soundscapePath = bundledAsset(
        rawSoundscape,
        what: 'page $pageNumber soundscape',
      );
      if (!assetExists(soundscapePath)) {
        fail('missing asset file: $soundscapePath');
      }
    }

    final rawOverlay = rawPage['overlay'];
    final overlay = rawOverlay is Map<String, dynamic>
        ? TextOverlayConfig.fromJson(rawOverlay)
        : null;

    pages.add(
      PageData(
        id: id,
        pageNumber: pageNumber,
        textContent: rawPage['textContent'] as String?,
        overlay: overlay,
        imageUrl: 'asset:///$imagePath',
        narrationUrl: narrationPath == null ? null : 'asset:///$narrationPath',
        soundscapeUrl: soundscapePath == null
            ? null
            : 'asset:///$soundscapePath',
        narrationTimestamps: timestamps,
      ),
    );
  }

  if (!assetExists(coverPath)) {
    fail('missing asset file: $coverPath');
  }

  final book = Book(
    id: sampleBookId,
    title: title,
    author: author.isEmpty ? null : author,
    coverUrl: 'asset:///$coverPath',
    pageCount: pages.length,
    pages: pages,
  );

  return SampleBookBundle(book: book, contentRevision: revision);
}

/// Production sample source: loads the bundled manifest, validates every
/// referenced file against the build's [AssetManifest], and throws
/// [SampleContentException] when the bundle is absent or broken.
Future<SampleBookBundle> loadBundledSample() async {
  late final String raw;
  try {
    raw = await rootBundle.loadString(_sampleManifestAssetPath);
  } catch (_) {
    throw const SampleContentException('sample bundle is not shipped');
  }

  final Object? decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw const SampleContentException('sample manifest is not an object');
  }

  final assetNames = await AssetManifest.loadFromAssetBundle(rootBundle);
  final shipped = assetNames.listAssets().toSet();
  bool assetExists(String path) => shipped.contains(path);

  return parseSampleManifest(decoded, assetExists: assetExists);
}

/// Riverpod provider for the bundled sample. Errors surface as
/// [SampleContentException]; entry points must treat error as "unavailable".
final sampleBookBundleProvider = FutureProvider<SampleBookBundle>((ref) {
  return loadBundledSample();
});
