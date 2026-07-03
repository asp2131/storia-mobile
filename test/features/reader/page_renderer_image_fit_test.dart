import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/features/reader/overlay/text_overlay_utils.dart';
import 'package:loratone/src/features/reader/page_renderer.dart';

void main() {
  test('contained image rect preserves source aspect on portrait phones', () {
    final rect = computeContainedImageRect(
      container: const Size(390, 844),
      sourceImage: const Size(1200, 800),
    );

    expect(rect.left, 0);
    expect(rect.right, 390);
    expect(rect.top, greaterThan(0));
    expect(rect.bottom, lessThan(844));
    expect(rect.width / rect.height, closeTo(1200 / 800, 0.001));
  });

  testWidgets('renders page images with contain fit to avoid cropping', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 844,
            child: PageRenderer(
              page: PageData(
                id: 'book-66-page-1',
                pageNumber: 1,
                imageUrl: 'https://example.com/book-66-page-1.png',
              ),
              narrationPosition: Duration.zero,
              isActive: true,
            ),
          ),
        ),
      ),
    );

    final pageImage = tester.widget<Image>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image && widget.image is CachedNetworkImageProvider,
      ),
    );

    expect(pageImage.fit, BoxFit.contain);
    expect(pageImage.width, double.infinity);
    expect(pageImage.height, double.infinity);
  });
}
