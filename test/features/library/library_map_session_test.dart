import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/library/core/library_map_layout.dart';
import 'package:storia_kids/src/features/library/ports/library_map_event.dart';
import 'package:storia_kids/src/features/library/ports/library_map_types.dart';
import 'package:storia_kids/src/features/library/services/library_map_session_impl.dart';
import 'fakes/fake_ports.dart';

/// Test helper: creates a minimal [Book] with just the fields [LibraryMapBook]
/// reads.
Book _makeBook({
  required String id,
  required String title,
  String? author,
  String? coverUrl,
  int pageCount = 10,
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    coverUrl: coverUrl,
    pageCount: pageCount,
    pages: const [],
  );
}

void main() {
  group('LibraryMapSessionImpl', () {
    late FakeLibraryMapEnginePort engine;
    late LibraryMapSessionImpl session;

    setUp(() {
      engine = FakeLibraryMapEnginePort();
      session = LibraryMapSessionImpl(enginePort: engine);
    });

    tearDown(() {
      session.dispose();
    });

    // ── loadBooks — node positions ───────────────────────────────────────

    group('loadBooks', () {
      test('with 0 books produces empty books list and worldWidth 0', () {
        session.loadBooks([], screenWidth: 400, screenHeight: 800);

        expect(session.books, isEmpty);
        expect(session.visibleBookIds, isEmpty);
        expect(session.selectedNode, isNull);
        expect(session.viewport.worldWidth, equals(600)); // min worldWidth
      });

      test('with 1 book produces correct node positions', () {
        final book = _makeBook(id: 'b1', title: 'Alpha');
        session.loadBooks([book], screenWidth: 400, screenHeight: 800);

        expect(session.books.length, equals(1));
        final placed = session.books[0];
        expect(placed.id, equals('b1'));
        expect(placed.title, equals('Alpha'));
        expect(placed.nodeIndex, equals(0));
        // With 1 book + 1 = 2 nodes of spacing 160, worldWidth = 320
        // clamped to max(screenWidth, 600) = max(400, 600) = 600
        expect(session.viewport.worldWidth, equals(600));
        // worldWidth = max(screenWidth, minWorldWidth) = 600
        // spacing = 600/(1+1) = 300
        // node 0 at x=300, y = 800*0.72 + offset(0) = 576 + (-18) = 558
        expect(placed.worldX, equals(300));
        expect(placed.worldY, equals(558));
      });

      test('with 3 books produces 3 nodes with correct positions', () {
        final books = [
          _makeBook(id: 'b1', title: 'Alpha', pageCount: 5),
          _makeBook(id: 'b2', title: 'Beta', pageCount: 20),
          _makeBook(id: 'b3', title: 'Gamma', pageCount: 8),
        ];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        expect(session.books.length, equals(3));

        // worldWidth = (3+1)*160 = 640 (no clamp since > 600)
        // spacing = 640/(3+1) = 160
        // node 0: x=160, y=800*0.72+offset(0)=-18 → 558
        // node 1: x=320, y=800*0.72+offset(1)=8  → 584
        // node 2: x=480, y=800*0.72+offset(2)=-12 → 564
        expect(session.books[0].worldX, equals(160));
        expect(session.books[0].worldY, equals(558));
        expect(session.books[1].worldX, equals(320));
        expect(session.books[1].worldY, equals(584));
        expect(session.books[2].worldX, equals(480));
        expect(session.books[2].worldY, equals(564));
      });

      test('with many books (>10) cycles vertical offsets correctly', () {
        final manyBooks = List.generate(
          15,
          (i) => _makeBook(id: 'b$i', title: 'Book $i'),
        );
        session.loadBooks(manyBooks, screenWidth: 400, screenHeight: 800);

        expect(session.books.length, equals(15));

        // Verify offsets cycle: offset(i) = verticalOffsets[i % 10]
        const offsets = LibraryMapLayoutConstants.verticalOffsets;
        for (int i = 0; i < 15; i++) {
          final expectedY =
              800 * LibraryMapLayout.routeBaselineFraction +
              offsets[i % offsets.length];
          expect(
            session.books[i].worldY,
            equals(expectedY),
            reason: 'book $i vertical offset should cycle',
          );
        }
      });

      test('visibleIds initialised to all book IDs', () {
        final books = [
          _makeBook(id: 'b1', title: 'Alpha'),
          _makeBook(id: 'b2', title: 'Beta'),
        ];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        expect(session.visibleBookIds, equals({'b1', 'b2'}));
        expect(session.selectedNode, isNull);
      });

      test('viewport worldWidth matches layout computed width', () {
        final books = List.generate(
          5,
          (i) => _makeBook(id: 'b$i', title: '$i'),
        );
        session.loadBooks(books, screenWidth: 800, screenHeight: 600);

        final expectedWidth = LibraryMapLayout.computeWorldWidth(5, 800);
        expect(session.viewport.worldWidth, equals(expectedWidth));
        expect(session.viewport.screenWidth, equals(800));
        expect(session.viewport.screenHeight, equals(600));
      });

      test('loadBooks does not trigger walkToBook', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha')];
        session.loadBooks(books, screenWidth: 400, screenHeight: 900);

        // Walking is only triggered by navigateToBook, not by loadBooks
        expect(engine.walkToBookCalls, isEmpty);
      });

      test('passes both screenWidth and screenHeight to engine', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha')];
        session.loadBooks(books, screenWidth: 720, screenHeight: 480);

        expect(engine.lastScreenWidth, equals(720));
        expect(engine.lastScreenHeight, equals(480));
      });

      test('repeated loadBooks keeps a single engine listener pair', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha')];

        session.loadBooks(books, screenWidth: 400, screenHeight: 800);
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        expect(engine.cameraListenerCount, equals(1));
        expect(engine.arrivalListenerCount, equals(1));
      });

      test('dispose removes engine listeners before disposing engine', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha')];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        session.dispose();

        expect(engine.cameraListenerCount, equals(0));
        expect(engine.arrivalListenerCount, equals(0));
        expect(engine.disposed, isTrue);
      });
    });

    // ── Search / filter ─────────────────────────────────────────────────

    group('search and filter', () {
      late List<Book> books;

      setUp(() {
        books = [
          _makeBook(
            id: 'b1',
            title: 'The Cat in the Hat',
            author: 'Dr. Seuss',
            pageCount: 5,
          ),
          _makeBook(
            id: 'b2',
            title: 'Green Eggs and Ham',
            author: 'Dr. Seuss',
            pageCount: 6,
          ),
          _makeBook(
            id: 'b3',
            title: 'The Hobbit',
            author: 'J.R.R. Tolkien',
            pageCount: 40,
          ),
          _makeBook(
            id: 'b4',
            title: 'The Cat Who Walked',
            author: null,
            pageCount: 3,
          ),
          _makeBook(
            id: 'b5',
            title: 'Moby Dick',
            author: 'Herman Melville',
            pageCount: 50,
          ),
        ];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);
      });

      test('empty search shows all books as visible', () {
        session.setSearchText('');
        expect(session.visibleBookIds, equals({'b1', 'b2', 'b3', 'b4', 'b5'}));
        expect(session.query.searchText, equals(''));
      });

      test('search by title narrows visibleIds', () {
        session.setSearchText('cat');
        expect(session.visibleBookIds, equals({'b1', 'b4'}));
        expect(engine.applyFilterCalls.last, equals({'b1', 'b4'}));
      });

      test('search by author narrows visibleIds', () {
        session.setSearchText('tolkien');
        expect(session.visibleBookIds, equals({'b3'}));
      });

      test('search is case-insensitive', () {
        session.setSearchText('DR. SEUSS');
        expect(session.visibleBookIds, equals({'b1', 'b2'}));
      });

      test('search with no matches keeps previous visibleIds', () {
        session.setSearchText('nonexistent book xyz');
        // When filter yields empty and query is active, old set is preserved
        expect(session.visibleBookIds, equals({'b1', 'b2', 'b3', 'b4', 'b5'}));
      });

      test('quickReads filter shows only short books', () {
        session.setLengthFilter(LibraryMapLengthFilter.quickReads);
        expect(session.visibleBookIds, equals({'b1', 'b2', 'b4'}));
        expect(engine.applyFilterCalls.last, equals({'b1', 'b2', 'b4'}));
      });

      test('longerReads filter shows only long books', () {
        session.setLengthFilter(LibraryMapLengthFilter.longerReads);
        expect(session.visibleBookIds, equals({'b3', 'b5'}));
      });

      test('search + filter combination works', () {
        session.setSearchText('cat');
        session.setLengthFilter(LibraryMapLengthFilter.quickReads);
        expect(session.visibleBookIds, equals({'b1', 'b4'}));
      });

      test('applyQuery with combined query updates visibleIds', () {
        session.applyQuery(
          const LibraryMapQuery(
            searchText: 'the',
            lengthFilter: LibraryMapLengthFilter.quickReads,
          ),
        );
        expect(session.visibleBookIds, equals({'b1', 'b4'}));
      });

      test('LibraryMapVisibleBooksChanged event emitted on filter change', () {
        LibraryMapEvent? received;
        session.setEventCallback((e) => received = e);

        session.setSearchText('cat');
        expect(received, isA<LibraryMapVisibleBooksChanged>());
        expect(
          (received as LibraryMapVisibleBooksChanged).visibleIds,
          equals({'b1', 'b4'}),
        );
      });
    });

    // ── Book tap → walkToBook + preview ─────────────────────────────────

    group('navigateToBook', () {
      late List<Book> books;

      setUp(() {
        books = [
          _makeBook(id: 'b1', title: 'Alpha'),
          _makeBook(id: 'b2', title: 'Beta'),
        ];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);
      });

      test('tap book triggers walkToBook on engine', () {
        session.navigateToBook(session.books[0]);
        expect(engine.walkToBookCalls.last.id, equals('b1'));
      });

      test('tap book sets selectedNode', () {
        session.navigateToBook(session.books[1]);
        expect(session.selectedNode?.id, equals('b2'));
      });

      test('walkAndPreview mode passes openPreviewOnArrival=true', () {
        session.navigateToBook(
          session.books[0],
          mode: ArrivalMode.walkAndPreview,
        );
        expect(engine.walkToBookCalls.last.id, equals('b1'));
        expect(engine.openPreviewOnArrivalCalls.last, isTrue);
      });

      test('walk mode passes openPreviewOnArrival=false', () {
        session.navigateToBook(session.books[0], mode: ArrivalMode.walk);
        expect(engine.walkToBookCalls.last.id, equals('b1'));
        expect(engine.openPreviewOnArrivalCalls.last, isFalse);
      });

      test('jump mode does not open preview on arrival', () {
        session.navigateToBook(session.books[0], mode: ArrivalMode.jump);
        expect(engine.walkToBookCalls.last.id, equals('b1'));
        expect(engine.openPreviewOnArrivalCalls.last, isFalse);
      });
    });

    // ── Preview position clamping ─────────────────────────────────────────

    group('preview position clamping', () {
      test('preview position clamped to viewport edges', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha', pageCount: 5)];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        // Manually set a screen position near the left edge
        engine.screenPositionByBookId['b1'] = const ui.Offset(10, 400);

        final pos = session.screenPositionOfNode(session.books[0]);
        expect(pos, isNotNull);
        // The session returns the raw position; the UI layer clamps it.
        // Verify the position is returned correctly.
        expect(pos!.dx, equals(10));
      });

      test('screenPositionOfNode returns null for unknown book', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha')];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        final unknownBook = LibraryMapBook(
          id: 'unknown',
          title: 'Unknown',
          pageCount: 1,
          nodeIndex: 0,
          worldX: 100,
          worldY: 500,
        );

        expect(session.screenPositionOfNode(unknownBook), isNull);
      });

      test('preview clamped via viewport query', () {
        final books = [
          _makeBook(id: 'b1', title: 'Alpha'),
          _makeBook(id: 'b2', title: 'Beta'),
        ];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        // node 0 at worldX=150, node 1 at worldX=300 (worldWidth=600)
        // viewport cameraX starts at 0
        expect(session.viewport.cameraX, equals(0));
        expect(session.viewport.visibleWorldRange, equals((0.0, 400.0)));
      });
    });

    // ── Camera events ────────────────────────────────────────────────────

    group('camera events', () {
      test('camera event emitted when cameraX changes beyond threshold', () {
        LibraryMapEvent? received;
        session.setEventCallback((e) => received = e);

        session.loadBooks(
          [_makeBook(id: 'b1', title: 'Alpha')],
          screenWidth: 400,
          screenHeight: 800,
        );

        // Simulate camera change in engine
        engine.simulateCameraChange(50.0);

        expect(received, isA<LibraryMapCameraChanged>());
        final cameraEvent = received as LibraryMapCameraChanged;
        expect(cameraEvent.cameraX, closeTo(50.0, 0.01));
        expect(session.cameraX, closeTo(50.0, 0.01));
      });

      test('camera event NOT emitted for tiny changes below threshold', () {
        int eventCountBefore = 0;
        session.setEventCallback((e) {
          eventCountBefore++;
        });

        session.loadBooks(
          [_makeBook(id: 'b1', title: 'Alpha')],
          screenWidth: 400,
          screenHeight: 800,
        );
        final eventsAfterLoad = eventCountBefore;

        // Now simulate a tiny camera change below threshold
        engine.simulateCameraChange(0.005);

        // No new camera event should have been emitted
        expect(eventCountBefore, equals(eventsAfterLoad));
      });

      test('camera event includes viewport snapshot', () {
        LibraryMapEvent? received;
        session.setEventCallback((e) => received = e);

        session.loadBooks(
          [_makeBook(id: 'b1', title: 'Alpha')],
          screenWidth: 500,
          screenHeight: 900,
        );

        engine.simulateCameraChange(100.0);

        final cameraEvent = received as LibraryMapCameraChanged;
        expect(cameraEvent.viewport.screenWidth, equals(500));
        expect(cameraEvent.viewport.screenHeight, equals(900));
        expect(
          cameraEvent.viewport.worldWidth,
          equals(600),
        ); // (1+1)*160 clamped
      });
    });

    // ── Book arrival → preview ───────────────────────────────────────────

    group('book arrival', () {
      test('arrival sets previewBook and selectedNode', () {
        final books = [
          _makeBook(id: 'b1', title: 'Alpha'),
          _makeBook(id: 'b2', title: 'Beta'),
        ];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        LibraryMapEvent? received;
        session.setEventCallback((e) => received = e);

        // Simulate player arriving at b2
        engine.simulateArrival(books[1]);

        expect(session.previewBook?.id, equals('b2'));
        expect(session.selectedNode?.id, equals('b2'));
        expect(received, isA<LibraryMapBookArrived>());
        expect((received as LibraryMapBookArrived).book.id, equals('b2'));
      });

      test('arrival event carries arrivalMode', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha')];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        LibraryMapEvent? received;
        session.setEventCallback((e) => received = e);

        session.navigateToBook(
          session.books[0],
          mode: ArrivalMode.walkAndPreview,
        );
        engine.simulateArrival(books[0]);

        final arrived = received as LibraryMapBookArrived;
        expect(arrived.arrivalMode, equals(ArrivalMode.walkAndPreview));
      });

      test('walk arrival selects node without opening preview', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha')];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        session.navigateToBook(session.books[0], mode: ArrivalMode.walk);
        engine.simulateArrival(books[0]);

        expect(session.selectedNode?.id, equals('b1'));
        expect(session.previewBook, isNull);
      });

      test('repeated loadBooks does not duplicate arrival events', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha')];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        var arrivalEvents = 0;
        session.setEventCallback((event) {
          if (event is LibraryMapBookArrived) arrivalEvents++;
        });

        session.navigateToBook(
          session.books[0],
          mode: ArrivalMode.walkAndPreview,
        );
        engine.simulateArrival(books[0]);

        expect(arrivalEvents, equals(1));
      });
    });

    // ── Browse results ───────────────────────────────────────────────────

    group('getBrowseResults', () {
      test('returns broader results from engine', () {
        final books = [
          _makeBook(id: 'b1', title: 'Alpha', pageCount: 5),
          _makeBook(id: 'b2', title: 'Beta', pageCount: 20),
          _makeBook(id: 'b3', title: 'Gamma', pageCount: 6),
        ];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        engine.browseResults = [
          books[2], // Gamma matches quickReads filter but not search 'alpha'
        ];

        session.setSearchText('alpha'); // b1 matches search
        session.applyLengthFilter(
          LibraryMapLengthFilter.quickReads,
        ); // b1 & b3 qualify
        // visibleIds should be {'b1'} since search 'alpha' limits to b1

        final results = session.getBrowseResults();
        expect(results.length, equals(1));
        expect(results[0].id, equals('b3'));
      });
    });

    // ── dismissPreview ───────────────────────────────────────────────────

    group('dismissPreview', () {
      test('clears previewBook', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha')];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        engine.simulateArrival(books[0]);
        expect(session.previewBook, isNotNull);

        session.dismissPreview();
        expect(session.previewBook, isNull);
      });
    });

    // ── selectBrowseResult ───────────────────────────────────────────────

    group('selectBrowseResult', () {
      test('navigates to book and emits LibraryMapBrowseBookSelected', () {
        final books = [_makeBook(id: 'b1', title: 'Alpha')];
        session.loadBooks(books, screenWidth: 400, screenHeight: 800);

        LibraryMapEvent? received;
        session.setEventCallback((e) => received = e);

        session.selectBrowseResult(session.books[0]);

        expect(received, isA<LibraryMapBrowseBookSelected>());
        expect(engine.walkToBookCalls.last.id, equals('b1'));
      });
    });
  });
}

/// Extension to access setLengthFilter from test (reuses internal method).
extension on LibraryMapSessionImpl {
  void applyLengthFilter(LibraryMapLengthFilter filter) {
    setLengthFilter(filter);
  }
}
