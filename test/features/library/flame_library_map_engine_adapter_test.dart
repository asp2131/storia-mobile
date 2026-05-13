import 'package:flutter_test/flutter_test.dart';

import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/library/adapters/flame_library_map_engine_adapter.dart';

Book _book(String id) =>
    Book(id: id, title: 'Book $id', pageCount: 10, pages: const []);

void main() {
  tearDown(() {
    FlameLibraryMapEngineAdapter.instance.dispose();
  });

  test('loadBooks sizes the world from screenWidth, not screenHeight', () {
    final adapter = FlameLibraryMapEngineAdapter.instance;

    adapter.loadBooks([_book('b1')], screenWidth: 900, screenHeight: 400);

    expect(adapter.game?.worldWidth, equals(900));
  });
}
