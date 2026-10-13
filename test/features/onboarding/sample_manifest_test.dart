import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/onboarding/data/sample_book_provider.dart';
import 'package:loratone/src/features/reader/domain/reader_capabilities.dart';

Map<String, dynamic> validManifest() => {
  'schemaVersion': 1,
  'bookId': sampleBookId,
  'contentRevision': '2026-10-05.1',
  'title': 'The Last Boat In',
  'author': 'Storia Studio',
  'coverUrl': 'asset:///assets/onboarding/sample/cover.png',
  'pages': [
    {
      'id': 'sample-page-1',
      'pageNumber': 1,
      'textContent': 'Thunder rolled across the harbor.',
      'imageUrl': 'asset:///assets/onboarding/sample/pages/1.png',
      'narrationUrl': 'asset:///assets/onboarding/sample/audio/1.mp3',
      'narrationTimestamps': [
        {'word': 'Thunder', 'start': 0.0, 'end': 0.6},
        {'word': 'rolled', 'start': 0.7, 'end': 1.2},
      ],
      'soundscapeUrl': 'asset:///assets/onboarding/sample/audio/harbor.mp3',
    },
    {
      'id': 'sample-page-2',
      'pageNumber': 2,
      'textContent': 'The last boat rowed toward the light.',
      'imageUrl': 'asset:///assets/onboarding/sample/pages/2.png',
    },
  ],
};

void main() {
  // All fixture paths exist as far as the verifier is concerned.
  bool stubExists(String path) => true;

  test('parses a valid manifest into a Book with bundled asset references', () {
    final bundle = parseSampleManifest(
      validManifest(),
      assetExists: stubExists,
    );

    expect(bundle.contentRevision, '2026-10-05.1');
    expect(bundle.book.id, sampleBookId);
    expect(bundle.book.title, 'The Last Boat In');
    expect(bundle.book.pages, hasLength(2));

    final page1 = bundle.book.pages.first;
    expect(page1.imageUrl, 'asset:///assets/onboarding/sample/pages/1.png');
    expect(page1.narrationUrl, 'asset:///assets/onboarding/sample/audio/1.mp3');
    expect(page1.narrationTimestamps, hasLength(2));
    expect(page1.narrationTimestamps!.first.word, 'Thunder');
    expect(
      page1.soundscapeUrl,
      'asset:///assets/onboarding/sample/audio/harbor.mp3',
    );

    // Silent page: narration optional, timestamps then absent.
    final page2 = bundle.book.pages[1];
    expect(page2.narrationUrl, isNull);
    expect(page2.narrationTimestamps, isNull);
  });

  test('rejects an unsupported schema version instead of guessing', () {
    final manifest = validManifest()..['schemaVersion'] = 2;
    expect(
      () => parseSampleManifest(manifest, assetExists: stubExists),
      throwsA(isA<SampleContentException>()),
    );
  });

  test('rejects a manifest whose bookId is not the reserved sample id', () {
    final manifest = validManifest()..['bookId'] = '42';
    expect(
      () => parseSampleManifest(manifest, assetExists: stubExists),
      throwsA(isA<SampleContentException>()),
    );
  });

  test('rejects remote (http) page media in the sample bundle', () {
    final manifest = validManifest();
    (manifest['pages'] as List)[0]['imageUrl'] = 'https://cdn.test/1.png';
    expect(
      () => parseSampleManifest(manifest, assetExists: stubExists),
      throwsA(isA<SampleContentException>()),
    );
  });

  test('rejects narration without aligned word timestamps', () {
    final manifest = validManifest();
    (manifest['pages'] as List)[0].remove('narrationTimestamps');
    expect(
      () => parseSampleManifest(manifest, assetExists: stubExists),
      throwsA(isA<SampleContentException>()),
    );
  });

  test('rejects duplicate or missing page ids', () {
    final dup = validManifest();
    (dup['pages'] as List)[1]['id'] = 'sample-page-1';
    expect(
      () => parseSampleManifest(dup, assetExists: stubExists),
      throwsA(isA<SampleContentException>()),
    );

    final missing = validManifest();
    (missing['pages'] as List)[0]['id'] = '';
    expect(
      () => parseSampleManifest(missing, assetExists: stubExists),
      throwsA(isA<SampleContentException>()),
    );
  });

  test('rejects a page without an illustration', () {
    final manifest = validManifest();
    (manifest['pages'] as List)[0].remove('imageUrl');
    expect(
      () => parseSampleManifest(manifest, assetExists: stubExists),
      throwsA(isA<SampleContentException>()),
    );
  });

  test('rejects a manifest whose referenced asset files are missing', () {
    bool nothingExists(String path) => false;
    expect(
      () => parseSampleManifest(validManifest(), assetExists: nothingExists),
      throwsA(isA<SampleContentException>()),
    );
  });

  test('rejects an empty page list', () {
    final manifest = validManifest()..['pages'] = <Map<String, dynamic>>[];
    expect(
      () => parseSampleManifest(manifest, assetExists: stubExists),
      throwsA(isA<SampleContentException>()),
    );
  });
}
