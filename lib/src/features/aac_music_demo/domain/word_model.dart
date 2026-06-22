// Vocabulary schema. A word's POSITION and SPEECH are sacred and stable.
// Musical role is OPTIONAL metadata and never alters speech.

enum MusicalRoleKind { note, chord, motif }

/// Stores a SCALE DEGREE, not an absolute pitch — resolved against the active
/// palette at play time, so the same word sounds right in any key.
class MusicalRole {
  const MusicalRole({
    required this.kind,
    required this.degree,
    this.voices = 3,
    this.motifDegrees = const [],
    this.gain = 0.55,
  });

  const MusicalRole.note(int degree, {double gain = 0.55})
      : this(kind: MusicalRoleKind.note, degree: degree, gain: gain);

  const MusicalRole.chord(int degree, {int voices = 3, double gain = 0.5})
      : this(
          kind: MusicalRoleKind.chord,
          degree: degree,
          voices: voices,
          gain: gain,
        );

  const MusicalRole.motif(List<int> degrees, {double gain = 0.5})
      : this(
          kind: MusicalRoleKind.motif,
          degree: 0,
          motifDegrees: degrees,
          gain: gain,
        );

  final MusicalRoleKind kind;
  final int degree;
  final int voices;
  final List<int> motifDegrees;

  /// Relative loudness (0..1). Always kept under the speech bus by the
  /// sequencer's headroom clamp.
  final double gain;
}

enum VocabRegion { core, fringe }

class AacWord {
  const AacWord({
    required this.id,
    required this.label,
    required this.row,
    required this.col,
    this.region = VocabRegion.core,
    this.tags = const [],
    this.auditoryIconAsset,
    this.musicalRole,
  });

  /// Stable identity — never changes across versions.
  final String id;

  /// Spoken/displayed text. This is the communicative function.
  final String label;

  final int row;
  final int col;
  final VocabRegion region;

  /// Semantic categories used by the role resolver for tag-default music.
  final List<String> tags;

  /// Optional curated sample (e.g. user's dog bark). Deferred from demo.
  final String? auditoryIconAsset;

  /// Optional explicit musical role; overrides any tag default.
  final MusicalRole? musicalRole;

  bool get isMusical => musicalRole != null;
  bool get hasAuditoryIcon => auditoryIconAsset != null;
}
