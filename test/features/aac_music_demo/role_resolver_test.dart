import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/aac_music_demo/domain/word_model.dart';
import 'package:loratone/src/features/aac_music_demo/domain/role_resolver.dart';

void main() {
  const config = BoardMusicConfig(
    tagDefaults: {
      'pronoun': MusicalRole.note(0),
      'request': MusicalRole.note(3),
      'quantity': MusicalRole.note(4),
    },
  );
  const resolver = RoleResolver(config);

  test('explicit musicalRole overrides tag default', () {
    const word = AacWord(
      id: 'i', label: 'I', row: 0, col: 0,
      tags: ['pronoun'],
      musicalRole: MusicalRole.note(2),
    );
    expect(resolver.resolveRole(word)!.degree, 2);
  });

  test('falls back to tag default when no override', () {
    const word = AacWord(
      id: 'want', label: 'want', row: 0, col: 1, tags: ['request'],
    );
    expect(resolver.resolveRole(word)!.degree, 3);
  });

  test('first matching tag wins when multiple tags', () {
    const word = AacWord(
      id: 'more', label: 'more', row: 0, col: 2, tags: ['quantity', 'request'],
    );
    expect(resolver.resolveRole(word)!.degree, 4); // quantity matched first
  });

  test('returns null when no override and no matching tag', () {
    const word = AacWord(id: 'go', label: 'go', row: 0, col: 3, tags: ['verb']);
    expect(resolver.resolveRole(word), isNull);
  });
}
