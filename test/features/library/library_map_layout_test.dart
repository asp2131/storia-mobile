import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/library/core/library_map_layout.dart';
import 'package:storia_kids/src/features/library/ports/library_map_types.dart';

/// Test helper: creates a minimal [Book].
Book _makeBook({
  required String id,
  required String title,
  int pageCount = 10,
}) {
  return Book(
    id: id,
    title: title,
    pageCount: pageCount,
    pages: const [],
  );
}

void main() {
  group('LibraryMapLayout', () {
    group('computeWorldWidth', () {
      test('0 books returns minWorldWidth', () {
        final width = LibraryMapLayout.computeWorldWidth(0, 400);
        expect(width, equals(600)); // minWorldWidth
      });

      test('1 book on small screen clamps to minWorldWidth', () {
        final width = LibraryMapLayout.computeWorldWidth(1, 400);
        expect(width, equals(600)); // (1+1)*160 = 320 clamped to max(400,600)
      });

      test('1 book on large screen returns needed width', () {
        final width = LibraryMapLayout.computeWorldWidth(1, 800);
        // (1+1)*160 = 320; max(800,600) = 800; no clamping needed
        expect(width, equals(800));
      });

      test('5 books returns (5+1)*spacing', () {
        final width = LibraryMapLayout.computeWorldWidth(5, 400);
        // (5+1)*160 = 960; no clamp needed since > 600
        expect(width, equals(960));
      });

      test('screenWidth larger than needed width takes precedence', () {
        final width = LibraryMapLayout.computeWorldWidth(1, 900);
        // (1+1)*160 = 320; max(900,600) = 900
        expect(width, equals(900));
      });
    });

    group('build', () {
      test('3 books produces 3 nodes', () {
        final books = [
          _makeBook(id: 'b1', title: 'Alpha'),
          _makeBook(id: 'b2', title: 'Beta'),
          _makeBook(id: 'b3', title: 'Gamma'),
        ];

        final layout = LibraryMapLayout.build(
          sourceBooks: books,
          screenWidth: 400,
          screenHeight: 800,
        );

        expect(layout.books.length, equals(3));
        expect(layout.screenWidth, equals(400));
        expect(layout.screenHeight, equals(800));
        // worldWidth = (3+1)*160 = 640, no clamp needed
        expect(layout.worldWidth, equals(640));
      });

      test('worldWidth derived from book count', () {
        final layout2 = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
            _makeBook(id: 'b2', title: 'B'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );
        // (2+1)*160 = 480 clamped to max(400,600) = 600
        expect(layout2.worldWidth, equals(600));

        final layout5 = LibraryMapLayout.build(
          sourceBooks: List.generate(5, (i) => _makeBook(id: 'b$i', title: '$i')),
          screenWidth: 400,
          screenHeight: 800,
        );
        // (5+1)*160 = 960
        expect(layout5.worldWidth, equals(960));
      });

      test('nodeIndex assigned sequentially 0..n-1', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'Alpha'),
            _makeBook(id: 'b2', title: 'Beta'),
            _makeBook(id: 'b3', title: 'Gamma'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        expect(layout.books[0].nodeIndex, equals(0));
        expect(layout.books[1].nodeIndex, equals(1));
        expect(layout.books[2].nodeIndex, equals(2));
      });
    });

    group('vertical offsets', () {
      test('offsets cycle correctly for 3 books', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'Alpha'),
            _makeBook(id: 'b2', title: 'Beta'),
            _makeBook(id: 'b3', title: 'Gamma'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        const offsets = LibraryMapLayoutConstants.verticalOffsets;
        expect(layout.books[0].worldY, equals(800 * 0.72 + offsets[0]));
        expect(layout.books[1].worldY, equals(800 * 0.72 + offsets[1]));
        expect(layout.books[2].worldY, equals(800 * 0.72 + offsets[2]));
      });

      test('offset at index cycles for >10 books', () {
        final books = List.generate(12, (i) => _makeBook(id: 'b$i', title: '$i'));
        final layout = LibraryMapLayout.build(
          sourceBooks: books,
          screenWidth: 400,
          screenHeight: 800,
        );

        const offsets = LibraryMapLayoutConstants.verticalOffsets;

        // Book 10 should cycle back to offsets[0]
        expect(
          layout.books[10].worldY,
          equals(800 * 0.72 + offsets[10 % offsets.length]),
        );

        // Book 11 should cycle back to offsets[1]
        expect(
          layout.books[11].worldY,
          equals(800 * 0.72 + offsets[11 % offsets.length]),
        );
      });

      test('verticalOffsetAt returns correct offset for any index', () {
        const offsets = LibraryMapLayoutConstants.verticalOffsets;
        for (int i = 0; i < 20; i++) {
          final expectedOffset = offsets[i % offsets.length];
          expect(
            LibraryMapLayout(
              books: const [],
              screenWidth: 400,
              screenHeight: 800,
              worldWidth: 600,
            ).verticalOffsetAt(i),
            equals(expectedOffset),
            reason: 'index $i should cycle to offsets[${i % offsets.length}]',
          );
        }
      });
    });

    group('waypoints / node positions', () {
      test('node positions are ordered left-to-right', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'First'),
            _makeBook(id: 'b2', title: 'Second'),
            _makeBook(id: 'b3', title: 'Third'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        expect(layout.books[0].worldX, lessThan(layout.books[1].worldX));
        expect(layout.books[1].worldX, lessThan(layout.books[2].worldX));
      });

      test('nodeSpacing computed correctly', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'Alpha'),
            _makeBook(id: 'b2', title: 'Beta'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        // worldWidth=600 (clamped), spacing = 600/3 = 200
        expect(layout.nodeSpacing, equals(200));
      });

      test('nodeXAt for consecutive indices', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
            _makeBook(id: 'b2', title: 'B'),
            _makeBook(id: 'b3', title: 'C'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        // spacing = 640 / 4 = 160
        expect(layout.nodeXAt(0), equals(160)); // 160 * (0+1) = 160
        expect(layout.nodeXAt(1), equals(320)); // 160 * (1+1) = 320
        expect(layout.nodeXAt(2), equals(480)); // 160 * (2+1) = 480
      });

      test('nodePositionAt returns Vector2', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
            _makeBook(id: 'b2', title: 'B'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        final pos0 = layout.nodePositionAt(0);
        expect(pos0.x, equals(layout.nodeXAt(0)));
        expect(pos0.y, equals(layout.nodeYAt(0)));
      });

      test('routeBaselineY equals screenHeight * 0.72', () {
        final layout = LibraryMapLayout(
          books: const [],
          screenWidth: 400,
          screenHeight: 800,
          worldWidth: 600,
        );

        expect(layout.routeBaselineY, equals(576)); // 800 * 0.72
      });

      test('nodePositionOfBook uses nodeIndex', () {
        final books = [
          _makeBook(id: 'b1', title: 'Alpha'),
          _makeBook(id: 'b2', title: 'Beta'),
        ];
        final layout = LibraryMapLayout.build(
          sourceBooks: books,
          screenWidth: 400,
          screenHeight: 800,
        );

        final pos0 = layout.nodePositionOfBook(layout.books[1]);
        expect(pos0.x, equals(layout.nodeXAt(1)));
        expect(pos0.y, equals(layout.nodeYAt(1)));
      });
    });

    group('computeVisibleIds', () {
      test('books within viewport range are visible', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
            _makeBook(id: 'b2', title: 'B'),
            _makeBook(id: 'b3', title: 'C'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        // worldWidth=640, spacing=160, nodes at 160, 320, 480
        // cameraX=0, visible [0-400], all 3 nodes in range
        final visible = layout.computeVisibleIds(0);
        expect(visible, equals({'b1', 'b2', 'b3'}));
      });

      test('books outside viewport range are not visible', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
            _makeBook(id: 'b2', title: 'B'),
            _makeBook(id: 'b3', title: 'C'),
          ],
          screenWidth: 200, // small viewport to force some out of range
          screenHeight: 800,
        );

        // worldWidth = (3+1)*160 = 640 (no clamp since > 600)
        // spacing = 640/4 = 160
        // nodes at 160, 320, 480
        // viewport width 200; cameraX=0 → visible [0,200]
        // only node at 160 is in range
        final visible = layout.computeVisibleIds(0);
        expect(visible, equals({'b1'}));
      });

      test('cameraX shifted right reveals later books', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
            _makeBook(id: 'b2', title: 'B'),
            _makeBook(id: 'b3', title: 'C'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        // cameraX=300, visible [300-80, 300+200+80]=[220, 580]
        // nodes at 160, 320, 480 → b2 and b3 in range (b1 at 160 < 220 out)
        final visible = layout.computeVisibleIds(300);
        expect(visible, equals({'b2', 'b3'}));
      });
    });

    group('screenOffsetOfNode', () {
      test('returns screen offset when node is in viewport', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        // worldWidth=600, spacing=300, node at x=300
        // nodeWorldX = 300 - 40 = 260; screenX = 260 - cameraX
        // with cameraX=0 → screenX=260, within [0,400]
        final offset = layout.screenOffsetOfNode(layout.books[0], 0);
        expect(offset, isNotNull);
        expect(offset!.dx, equals(260));
        expect(offset.dy, equals(layout.books[0].worldY));
      });

      test('returns null when node is off-screen left', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        // node at worldX=300; with cameraX=500, screenX = 300-40-500 = -240
        // outside viewport [500, 900] → null
        final offset = layout.screenOffsetOfNode(layout.books[0], 500);
        expect(offset, isNull);
      });

      test('returns null when node is off-screen right', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
          ],
          screenWidth: 200, // small viewport
          screenHeight: 800,
        );

        // worldWidth = (1+1)*160 = 320 → clamped to max(200,600)=600
        // spacing = 600/2 = 300, node at 300
        // nodeWorldX = 300-40 = 260
        // cameraX=0 → screenX = 260, outside [0,200] → null
        final offset = layout.screenOffsetOfNode(layout.books[0], 0);
        expect(offset, isNull);

        // cameraX=400 → screenX = 160-40-400 = -280, outside
        final offsetFar = layout.screenOffsetOfNode(layout.books[0], 400);
        expect(offsetFar, isNull);
      });
    });

    group('equality', () {
      test('identical layouts are equal', () {
        final layout1 = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );
        final layout2 = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        expect(layout1, equals(layout2));
        expect(layout1.hashCode, equals(layout2.hashCode));
      });

      test('different screenWidth produces different layout', () {
        final layout1 = LibraryMapLayout.build(
          sourceBooks: [_makeBook(id: 'b1', title: 'A')],
          screenWidth: 400,
          screenHeight: 800,
        );
        final layout2 = LibraryMapLayout.build(
          sourceBooks: [_makeBook(id: 'b1', title: 'A')],
          screenWidth: 800,
          screenHeight: 800,
        );

        expect(layout1, isNot(equals(layout2)));
      });
    });

    group('LibraryMapLayoutConstants', () {
      test('verticalOffsets cycle length is 10', () {
        expect(LibraryMapLayoutConstants.verticalOffsets.length, equals(10));
      });

      test('nodeWidth is 80', () {
        expect(LibraryMapLayoutConstants.nodeWidth, equals(80));
      });

      test('spacingPerNode is 160', () {
        expect(LibraryMapLayoutConstants.spacingPerNode, equals(160));
      });

      test('minWorldWidth is 600', () {
        expect(LibraryMapLayoutConstants.minWorldWidth, equals(600));
      });
    });

    group('maxCameraX', () {
      test('returns worldWidth - screenWidth when world is scrollable', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [
            _makeBook(id: 'b1', title: 'A'),
            _makeBook(id: 'b2', title: 'B'),
          ],
          screenWidth: 400,
          screenHeight: 800,
        );

        // worldWidth=600, screenWidth=400 → maxCameraX=200
        expect(layout.maxCameraX, equals(200));
      });

      test('returns 0 when world fits in viewport', () {
        final layout = LibraryMapLayout.build(
          sourceBooks: [_makeBook(id: 'b1', title: 'A')],
          screenWidth: 800, // wide screen, worldWidth=800
          screenHeight: 800,
        );

        // worldWidth=800, screenWidth=800 → no scroll needed
        expect(layout.maxCameraX, equals(0));
      });
    });
  });
}