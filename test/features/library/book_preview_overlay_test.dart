import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/features/library/game/book_preview_overlay.dart';
import 'package:loratone/src/features/narration_studio/application/narration_track_selection.dart';
import 'package:loratone/src/features/narration_studio/domain/narration_track.dart';

Future<void> _pumpPreview(
  WidgetTester tester,
  Book book, {
  double textScale = 1,
  Offset position = const Offset(160, 400),
  VoidCallback? onRead,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Stack(
          children: [
            BookPreviewOverlay(
              book: book,
              onRead: onRead ?? () {},
              onDismiss: () {},
              position: position,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('library map preview identifies the book and opens reading', (
    tester,
  ) async {
    final book = Book.fromLibraryJson({
      'id': '1',
      'title': 'A library book',
      'author': 'A creator',
      'pages': [
        {'count': 8},
      ],
    });

    var didRead = false;
    await _pumpPreview(tester, book, onRead: () => didRead = true);
    expect(find.text('A library book'), findsOneWidget);
    expect(find.text('A creator'), findsOneWidget);
    expect(find.text('8 pages'), findsOneWidget);
    expect(didRead, isFalse);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    expect(didRead, isTrue);
  });

  testWidgets('parent narration remains readable in a narrow scaled preview', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 320);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final book = Book.fromJson({
      'id': '1',
      'title': 'A long title for a narrow library preview',
      'author': 'A creator with a long name',
      'pages': [
        {'id': '1', 'page_number': 1, 'text_content': 'Hello'},
      ],
    });
    final narratedBook = applyTrackToBook(
      book,
      NarrationTrack(
        id: 'track',
        bookId: '1',
        label: 'Parent',
        isReady: true,
        pages: const [
          NarrationPageRecording(
            pageId: '1',
            pageNumber: 1,
            audioUrl: 'https://example.test/parent.m4a',
            wordCount: 1,
            alignment: NarrationAlignment.aligned,
            wordTimestamps: [WordTimestamp(word: 'Hello', start: 0, end: 1)],
          ),
        ],
      ),
    );
    var didRead = false;
    await _pumpPreview(
      tester,
      narratedBook,
      textScale: 2,
      // The library positions the card; keep it inside this test viewport.
      position: const Offset(140, 16),
      onRead: () => didRead = true,
    );
    expect(tester.takeException(), isNull);
    final readButton = find.byIcon(Icons.play_arrow_rounded);
    expect(readButton.hitTestable(), findsOneWidget);
    expect(didRead, isFalse);
    await tester.tap(readButton);
    expect(didRead, isTrue);
    expect(tester.takeException(), isNull);
  });
}
