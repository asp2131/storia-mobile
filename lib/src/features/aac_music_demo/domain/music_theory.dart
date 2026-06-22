// Foundational musical primitives. No Flutter imports — pure Dart.
// Core guarantee: every sound is drawn from one HarmonicPalette (key+scale),
// so any combination of words is consonant by construction.

enum PitchClass {
  c, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b;

  int get semitone => index;
}

/// Ordered semitone offsets from the root. Pentatonic has no semitone
/// clashes — the "can't sound bad" default for the MVP.
enum Scale {
  majorPentatonic([0, 2, 4, 7, 9]),
  minorPentatonic([0, 3, 5, 7, 10]),
  major([0, 2, 4, 5, 7, 9, 11]),
  lydian([0, 2, 4, 6, 7, 9, 11]);

  const Scale(this.intervals);
  final List<int> intervals;
  int get degreeCount => intervals.length;
}

/// A concrete pitch as a MIDI note number (60 = middle C). MIDI is the
/// universal currency for both flutter_midi_pro and pre-rendered samples.
class Pitch {
  const Pitch(this.midi);
  final int midi;

  String get label {
    const names = [
      'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
    ];
    final octave = (midi ~/ 12) - 1;
    return '${names[midi % 12]}$octave';
  }

  Pitch transpose(int semitones) => Pitch(midi + semitones);

  @override
  bool operator ==(Object other) => other is Pitch && other.midi == midi;

  @override
  int get hashCode => midi.hashCode;

  @override
  String toString() => '$label($midi)';
}

/// The single key + scale the whole board is tuned to. Never change
/// mid-utterance — that is what keeps a built sentence in key.
class HarmonicPalette {
  const HarmonicPalette({
    required this.root,
    this.scale = Scale.majorPentatonic,
    this.baseOctave = 4,
  });

  final PitchClass root;
  final Scale scale;
  final int baseOctave;

  int get rootMidi => (baseOctave + 1) * 12 + root.semitone;

  /// degree 0 = root; degrees beyond the scale length wrap up octaves.
  Pitch pitchForDegree(int degree) {
    final n = scale.degreeCount;
    final octaveShift = degree ~/ n;
    final within = degree % n;
    return Pitch(rootMidi + scale.intervals[within] + 12 * octaveShift);
  }

  /// Stacks within the scale (every other degree). Diatonic + consonant by
  /// construction. NOTE: in pentatonic this is a "stacked chord", not a
  /// classical triad.
  List<Pitch> chordForDegree(int degree, {int voices = 3}) {
    return List.generate(voices, (i) => pitchForDegree(degree + i * 2));
  }

  @override
  String toString() => '${root.name}-${scale.name}@oct$baseOctave';
}
