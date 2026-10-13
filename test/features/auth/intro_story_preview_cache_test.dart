import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/file.dart' as cache_file;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/auth/data/intro_preview_image_provider.dart';
import 'package:loratone/src/features/auth/presentation/widgets/intro_preview_illustration.dart';

class _PreviewCache extends Fake implements BaseCacheManager {
  _PreviewCache(this.file);

  final cache_file.File file;
  int loads = 0;

  @override
  Future<cache_file.File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    loads++;
    return file;
  }
}

class _CachedFile extends Fake implements cache_file.File {
  _CachedFile(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> readAsBytes() async => bytes;
}

void main() {
  testWidgets(
    'intro illustration survives route replacement and image-cache eviction',
    (tester) async {
      final cache = _PreviewCache(
        _CachedFile(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAYAAADED76LAAAAFklEQVR4nGP8P4PhPwMewIRPcvgoAACt6wKmSGuu1gAAAABJRU5ErkJggg==',
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [introPreviewCacheManagerProvider.overrideWithValue(cache)],
      );
      addTearDown(container.dispose);
      final navigator = GlobalKey<NavigatorState>();
      const preview = Scaffold(
        body: SizedBox(
          width: 390,
          height: 420,
          child: IntroPreviewIllustration(imageUrl: _imageUrl),
        ),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(navigatorKey: navigator, home: preview),
        ),
      );
      await tester.runAsync(
        () => container.read(introPreviewImageProvider(_imageUrl).future),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          container.read(introPreviewImageProvider(_imageUrl)).requireValue,
          tester.element(find.byType(IntroPreviewIllustration)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image!.width, 8);

      navigator.currentState!.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Another screen')),
        ),
      );
      await tester.pumpAndSettle();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      navigator.currentState!.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => preview),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          container.read(introPreviewImageProvider(_imageUrl)).requireValue,
          tester.element(find.byType(IntroPreviewIllustration)),
        ),
      );
      await tester.pumpAndSettle();
      final returnedFrame = tester
          .widget<RawImage>(find.byType(RawImage))
          .image!;
      expect(returnedFrame.width, 8);
      expect(
        cache.loads,
        1,
        reason:
            'Returning must decode retained bytes without refetching the illustration.',
      );
      final pixels = await tester.runAsync(() => returnedFrame.toByteData());
      expect(pixels!.getUint8(0), 255);
      expect(pixels.getUint8(1), 152);
      expect(pixels.getUint8(3), 255);
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    },
  );
}

const _imageUrl = 'https://example.test/soccer-page.png';
