// Parses the board JSON asset into domain objects. Hand-written (no codegen,
// per repo convention).

import 'dart:convert';

import '../domain/music_theory.dart';
import '../domain/role_resolver.dart';
import '../domain/word_model.dart';

class AacBoard {
  const AacBoard({
    required this.palette,
    required this.musicConfig,
    required this.words,
  });

  final HarmonicPalette palette;
  final BoardMusicConfig musicConfig;
  final List<AacWord> words;

  factory AacBoard.fromJsonString(String source) =>
      AacBoard.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory AacBoard.fromJson(Map<String, dynamic> json) {
    return AacBoard(
      palette: _paletteFromJson(json['palette'] as Map<String, dynamic>),
      musicConfig: BoardMusicConfig(
        tagDefaults: _roleMap(json['tagDefaults'] as Map<String, dynamic>?),
      ),
      words: (json['words'] as List<dynamic>)
          .map((w) => _wordFromJson(w as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  static HarmonicPalette _paletteFromJson(Map<String, dynamic> j) {
    return HarmonicPalette(
      root: PitchClass.values.byName(j['root'] as String),
      scale: Scale.values.byName(j['scale'] as String? ?? 'majorPentatonic'),
      baseOctave: (j['baseOctave'] as num?)?.toInt() ?? 4,
    );
  }

  static Map<String, MusicalRole> _roleMap(Map<String, dynamic>? j) {
    if (j == null) return const {};
    return j.map(
      (k, v) => MapEntry(k, _roleFromJson(v as Map<String, dynamic>)),
    );
  }

  static MusicalRole _roleFromJson(Map<String, dynamic> j) {
    final kind = MusicalRoleKind.values.byName(j['kind'] as String);
    final degree = (j['degree'] as num?)?.toInt() ?? 0;
    final gain = (j['gain'] as num?)?.toDouble();
    switch (kind) {
      case MusicalRoleKind.note:
        return gain == null
            ? MusicalRole.note(degree)
            : MusicalRole.note(degree, gain: gain);
      case MusicalRoleKind.chord:
        final voices = (j['voices'] as num?)?.toInt() ?? 3;
        return gain == null
            ? MusicalRole.chord(degree, voices: voices)
            : MusicalRole.chord(degree, voices: voices, gain: gain);
      case MusicalRoleKind.motif:
        final degrees = ((j['motifDegrees'] as List<dynamic>?) ?? const [])
            .map((d) => (d as num).toInt())
            .toList();
        return gain == null
            ? MusicalRole.motif(degrees)
            : MusicalRole.motif(degrees, gain: gain);
    }
  }

  static AacWord _wordFromJson(Map<String, dynamic> j) {
    final roleJson = j['musicalRole'] as Map<String, dynamic>?;
    return AacWord(
      id: j['id'] as String,
      label: j['label'] as String,
      row: (j['row'] as num).toInt(),
      col: (j['col'] as num).toInt(),
      region: VocabRegion.values.byName(j['region'] as String? ?? 'core'),
      tags: ((j['tags'] as List<dynamic>?) ?? const [])
          .map((t) => t as String)
          .toList(),
      auditoryIconAsset: j['auditoryIconAsset'] as String?,
      musicalRole: roleJson == null ? null : _roleFromJson(roleJson),
    );
  }
}
