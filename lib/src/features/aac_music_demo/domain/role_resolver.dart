// Hybrid music identity: explicit word override wins; otherwise the first
// matching semantic tag's default applies; otherwise the word has no music.

import 'word_model.dart';

class BoardMusicConfig {
  const BoardMusicConfig({this.tagDefaults = const {}});

  /// Maps a semantic tag (e.g. 'pronoun') to its default MusicalRole.
  final Map<String, MusicalRole> tagDefaults;
}

class RoleResolver {
  const RoleResolver(this.config);
  final BoardMusicConfig config;

  /// Precedence: word.musicalRole -> first matching tag default -> null.
  MusicalRole? resolveRole(AacWord word) {
    if (word.musicalRole != null) return word.musicalRole;
    for (final tag in word.tags) {
      final def = config.tagDefaults[tag];
      if (def != null) return def;
    }
    return null;
  }
}
