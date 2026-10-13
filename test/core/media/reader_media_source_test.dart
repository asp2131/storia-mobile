import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/core/media/reader_media_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderMediaSource.parse', () {
    test('parses a bundled asset URI into an asset path', () {
      final source = ReaderMediaSource.parse(
        'asset:///assets/onboarding/sample/pages/page-1.png',
      );
      expect(source, isA<AssetReaderMediaSource>());
      expect(source.assetPath, 'assets/onboarding/sample/pages/page-1.png');
    });

    test('passes an HTTP(S) resource through as a network source', () {
      final source = ReaderMediaSource.parse(
        'https://cdn.example.com/books/42/pages/1.png',
      );
      expect(source, isA<NetworkReaderMediaSource>());
      expect(source.uri, Uri.parse('https://cdn.example.com/books/42/pages/1.png'));
    });

    test('empty and null sources resolve to nothing', () {
      expect(ReaderMediaSource.parse(null), isA<EmptyReaderMediaSource>());
      expect(ReaderMediaSource.parse(''), isA<EmptyReaderMediaSource>());
    });

    test('rejects non-asset, non-http schemes instead of guessing', () {
      expect(
        () => ReaderMediaSource.parse('file:///etc/passwd'),
        throwsArgumentError,
      );
      expect(
        () => ReaderMediaSource.parse('asset://relative.png'),
        throwsArgumentError,
      );
    });

    test('rejects an asset path escaping the sample bundle', () {
      expect(
        () => ReaderMediaSource.parse('asset:///../secrets/.env'),
        throwsArgumentError,
      );
    });
  });

  group('imageProviderForReaderSource', () {
    test('asset sources map to AssetImage', () {
      final provider = imageProviderForReaderSource(
        'asset:///assets/onboarding/sample/pages/page-1.png',
      );
      expect(provider, isA<AssetImage>());
    });

    test('network sources map to the shared cache provider', () {
      final provider = imageProviderForReaderSource(
        'https://cdn.example.com/pages/1.png',
        cacheManager: _NoopCacheManager(),
      );
      expect(provider, isA<CachedNetworkImageProvider>());
    });

    test('empty sources map to nothing', () {
      expect(imageProviderForReaderSource(null), isNull);
      expect(imageProviderForReaderSource(''), isNull);
    });
  });
}

class _NoopCacheManager implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
