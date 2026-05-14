import 'package:flutter_test/flutter_test.dart';

import 'package:storia_kids/src/features/library/ports/library_map_event.dart';
import 'package:storia_kids/src/features/library/ports/library_map_types.dart';

void main() {
  test('LibraryMapEvent.occurredAt is stable across reads', () async {
    final event = LibraryMapVisibleBooksChanged(visibleIds: {'book-1'});

    final firstRead = event.occurredAt;
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final secondRead = event.occurredAt;

    expect(secondRead, same(firstRead));
  });

  test('LibraryMapCameraChanged snapshots its creation time', () async {
    final event = LibraryMapCameraChanged(
      cameraX: 0,
      viewport: const LibraryMapViewport(
        screenWidth: 400,
        screenHeight: 800,
        cameraX: 0,
        worldWidth: 600,
      ),
    );

    final emittedAt = event.occurredAt;
    await Future<void>.delayed(const Duration(milliseconds: 2));

    expect(event.occurredAt, same(emittedAt));
  });
}
