// Resolves palette-independent MusicalRoles into concrete Pitches and keeps
// any combination consonant. Because everything is in-key already, voicing
// only nudges octaves — it can never introduce a wrong note.

import 'music_theory.dart';
import 'word_model.dart';

class ResolvedVoice {
  const ResolvedVoice(this.pitches, this.gain, this.kind);
  final List<Pitch> pitches; // 1 = note, >1 = chord/motif anchor
  final double gain;
  final MusicalRoleKind kind;
}

class ConsonanceEngine {
  const ConsonanceEngine(this.palette, {this.minSimultaneousGap = 2});

  final HarmonicPalette palette;

  /// Minimum semitone gap between simultaneous voices. 2 = no minor seconds.
  final int minSimultaneousGap;

  ResolvedVoice resolve(MusicalRole role) {
    switch (role.kind) {
      case MusicalRoleKind.note:
        return ResolvedVoice(
          [palette.pitchForDegree(role.degree)],
          role.gain,
          role.kind,
        );
      case MusicalRoleKind.chord:
        return ResolvedVoice(
          palette.chordForDegree(role.degree, voices: role.voices),
          role.gain,
          role.kind,
        );
      case MusicalRoleKind.motif:
        return ResolvedVoice(
          role.motifDegrees.map(palette.pitchForDegree).toList(),
          role.gain,
          role.kind,
        );
    }
  }

  List<Pitch> deClash(List<Pitch> pitches) {
    final sorted = [...pitches]..sort((a, b) => a.midi.compareTo(b.midi));
    final result = <Pitch>[];
    for (final p in sorted) {
      var candidate = p;
      while (result.any(
        (q) => (q.midi - candidate.midi).abs() < minSimultaneousGap,
      )) {
        candidate = candidate.transpose(12);
      }
      result.add(candidate);
    }
    return result;
  }

  /// Collapses a whole utterance into one resolved chord for the "bloom".
  /// Keeps one instance per pitch class, then de-clashes the survivors.
  List<Pitch> bloomChord(List<ResolvedVoice> voices) {
    final all = voices.expand((v) => v.pitches).toList()
      ..sort((a, b) => a.midi.compareTo(b.midi));
    final seenClass = <int>{};
    final unique = <Pitch>[];
    for (final p in all) {
      if (seenClass.add(p.midi % 12)) unique.add(p);
    }
    return deClash(unique);
  }
}
