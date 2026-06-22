import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/music_theory.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/word_model.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/consonance_engine.dart';

void main() {
  const palette = HarmonicPalette(root: PitchClass.c, scale: Scale.majorPentatonic);
  const engine = ConsonanceEngine(palette);

  test('resolve note returns single in-key pitch', () {
    final v = engine.resolve(const MusicalRole.note(2));
    expect(v.pitches.map((p) => p.midi).toList(), [64]); // E4
    expect(v.kind, MusicalRoleKind.note);
  });

  test('resolve chord returns stacked in-key pitches', () {
    final v = engine.resolve(const MusicalRole.chord(0));
    expect(v.pitches.map((p) => p.midi).toList(), [60, 64, 69]);
  });

  test('deClash lifts octaves so no two notes sit within a minor second', () {
    final clashing = [const Pitch(60), const Pitch(61)];
    final spaced = engine.deClash(clashing);
    for (var i = 0; i < spaced.length; i++) {
      for (var j = i + 1; j < spaced.length; j++) {
        expect((spaced[i].midi - spaced[j].midi).abs() >= 2, isTrue);
      }
    }
  });

  test('bloomChord of all musical words stays in key with no clashes', () {
    final roles = const [
      MusicalRole.note(0),
      MusicalRole.note(2),
      MusicalRole.note(4),
      MusicalRole.chord(0),
    ];
    final voices = roles.map(engine.resolve).toList();
    final bloom = engine.bloomChord(voices);

    final inKey = bloom.every(
      (p) => palette.scale.intervals.contains((p.midi - palette.rootMidi) % 12),
    );
    expect(inKey, isTrue);

    final midis = bloom.map((p) => p.midi).toList();
    for (var i = 0; i < midis.length; i++) {
      for (var j = i + 1; j < midis.length; j++) {
        expect((midis[i] - midis[j]).abs() >= 2, isTrue);
      }
    }
  });
}
