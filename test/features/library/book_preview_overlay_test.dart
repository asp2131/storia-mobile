import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/features/library/catalog_copy.dart';
import 'package:loratone/src/features/library/game/book_preview_overlay.dart';
import 'package:loratone/src/features/library/ports/library_map_types.dart';
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
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
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
  testWidgets('library map round trip keeps the human artwork explanation', (
    tester,
  ) async {
    final book = LibraryMapBook.fromBook(
      Book.fromLibraryJson({
        'id': '1',
        'title': 'A library book',
        'author': 'A creator',
        'artwork_provenance': 'human_created',
        'pages': [
          {'count': 8},
        ],
      }),
      nodeIndex: 0,
      worldX: 100,
      worldY: 300,
    ).toBook();

    await _pumpPreview(tester, book);
    final badge = find.widgetWithText(
      TextButton,
      CatalogCopy.humanCreatedArtwork,
    );
    expect(badge, findsOneWidget);
    await tester.tap(badge);
    await tester.pumpAndSettle();
    expect(find.text(CatalogCopy.humanCreatedArtworkExplanation), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text(CatalogCopy.humanCreatedArtworkExplanation), findsNothing);
    expect(badge, findsOneWidget);
  });

  testWidgets('non-human and unrecognized metadata never make a human claim', (
    tester,
  ) async {
    final rows = <Map<String, dynamic>>[
      {},
      {'artwork_provenance': null},
      {'artwork_provenance': 'unspecified'},
      {'artwork_provenance': 'ai_assisted_or_generated'},
      {'artwork_provenance': 'future_classification'},
      {'artwork_provenance': true},
      {'artwork_provenance': ' human_created '},
    ];
    for (final row in rows) {
      for (final parse in [Book.fromLibraryJson, Book.fromJson]) {
        await _pumpPreview(tester, parse({'id': '1', 'title': 'Book', ...row}));
        expect(
          find.widgetWithText(TextButton, CatalogCopy.humanCreatedArtwork),
          findsNothing,
        );
      }
    }
  });

  testWidgets('parent narration keeps artwork info reachable on a small viewport', (
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
      'artwork_provenance': 'human_created',
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
      position: const Offset(270, 310),
      onRead: () => didRead = true,
    );
    expect(tester.takeException(), isNull);
    final badge = find.widgetWithText(
      TextButton,
      CatalogCopy.humanCreatedArtwork,
    );
    await tester.ensureVisible(badge);
    await tester.pumpAndSettle();
    await tester.tap(badge);
    await tester.pumpAndSettle();
    expect(find.text(CatalogCopy.humanCreatedArtworkExplanation), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    final readButton = find.byIcon(Icons.play_arrow_rounded);
    await tester.ensureVisible(readButton);
    await tester.pumpAndSettle();
    await tester.tap(readButton);
    expect(didRead, isTrue);
    expect(tester.takeException(), isNull);
  });
}
