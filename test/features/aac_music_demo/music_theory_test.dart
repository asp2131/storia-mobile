import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/aac_music_demo/domain/music_theory.dart';

void main() {
  group('HarmonicPalette major pentatonic', () {
    const palette = HarmonicPalette(
      root: PitchClass.c,
      scale: Scale.majorPentatonic,
      baseOctave: 4,
    );

    test('rootMidi is middle C (60)', () {
      expect(palette.rootMidi, 60);
    });

    test('degrees resolve to C D E G A then wrap an octave', () {
      expect(palette.pitchForDegree(0).midi, 60); // C4
      expect(palette.pitchForDegree(1).midi, 62); // D4
      expect(palette.pitchForDegree(2).midi, 64); // E4
      expect(palette.pitchForDegree(3).midi, 67); // G4
      expect(palette.pitchForDegree(4).midi, 69); // A4
      expect(palette.pitchForDegree(5).midi, 72); // C5 (wrap)
    });

    test('chordForDegree stacks scale degrees (every other degree)', () {
      final chord = palette.chordForDegree(0, voices: 3);
      expect(chord.map((p) => p.midi).toList(), [60, 64, 69]); // C E A
    });

    test('Pitch.label is human readable', () {
      expect(const Pitch(60).label, 'C4');
      expect(const Pitch(69).label, 'A4');
    });
  });
}
