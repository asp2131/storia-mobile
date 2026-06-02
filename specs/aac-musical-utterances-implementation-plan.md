# AAC Musical Utterances Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone AAC sentence-builder demo where tapping words speaks them (TTS) and plays in-key musical notes, and "send" speaks the full sentence then resolves the utterance into a soft bloom chord.

**Architecture:** A pure-Dart, Flutter-free core (music theory → consonance engine → role resolver → sequencer) is TDD'd against fake backends. Thin adapters implement speech (`flutter_tts`) and music (`flutter_midi_pro`) behind interfaces. A Riverpod-driven demo screen renders a fixed board loaded from a JSON asset. Every musical pitch is a scale degree resolved against one major-pentatonic palette, guaranteeing consonance by construction; music gain is always clamped under speech.

**Tech Stack:** Flutter, Riverpod 2.6.1 (no codegen), `go_router`, vendored `flutter_tts`, `flutter_midi_pro`, `flutter_test`. Design tokens: `StoriaColors`, `StoriaSpacing`. Reference design: `specs/aac-musical-utterances-design.md`.

---

## File Structure

```
lib/src/features/aac_music_demo/
  domain/
    music_theory.dart          # PitchClass, Scale, Pitch, HarmonicPalette
    word_model.dart            # MusicalRoleKind, MusicalRole, VocabRegion, AacWord
    consonance_engine.dart     # ResolvedVoice, ConsonanceEngine
    role_resolver.dart         # BoardMusicConfig, RoleResolver
    sequencer.dart             # SpeechSynth, AudioBackend, MusicMode, SequencerConfig, UtteranceSequencer
  data/
    aac_board.dart             # AacBoard model + JSON parsing
    aac_board_loader.dart      # loads/parses the JSON asset
  adapters/
    flutter_tts_speech_synth.dart   # SpeechSynth via vendored flutter_tts
    midi_audio_backend.dart         # AudioBackend via flutter_midi_pro (+ warm-up)
  presentation/
    aac_music_demo_controller.dart  # Riverpod StateNotifier: utterance/mode/send
    aac_music_demo_screen.dart      # board UI (replaces current placeholder)
assets/aac/demo_board.json          # vocabulary + music mapping + palette config
assets/aac/soundfonts/<name>.sf2    # soft soundfont (added in Task 9)

test/features/aac_music_demo/
  music_theory_test.dart
  consonance_engine_test.dart
  role_resolver_test.dart
  sequencer_test.dart
  aac_board_test.dart
  aac_music_demo_controller_test.dart
  aac_music_demo_screen_test.dart
```

Each `domain/` file has one responsibility and no Flutter import (unit-testable in pure Dart). Adapters are the only files importing the plugins. The controller is the only place Riverpod state lives.

---

## Task 1: Music theory primitives

**Files:**
- Create: `lib/src/features/aac_music_demo/domain/music_theory.dart`
- Test: `test/features/aac_music_demo/music_theory_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/aac_music_demo/music_theory_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/music_theory.dart';

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/aac_music_demo/music_theory_test.dart`
Expected: FAIL — `music_theory.dart` / symbols not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/features/aac_music_demo/domain/music_theory.dart
//
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/aac_music_demo/music_theory_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/aac_music_demo/domain/music_theory.dart test/features/aac_music_demo/music_theory_test.dart
git commit -m "feat(aac): add music theory primitives (palette, scale, pitch)"
```

---

## Task 2: Word model

**Files:**
- Create: `lib/src/features/aac_music_demo/domain/word_model.dart`
- Test: covered indirectly by Task 3/4; add a focused test file.
- Test: `test/features/aac_music_demo/word_model_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/aac_music_demo/word_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/word_model.dart';

void main() {
  test('AacWord without a role is not musical', () {
    const word = AacWord(id: 'go', label: 'go', row: 0, col: 0);
    expect(word.isMusical, isFalse);
    expect(word.tags, isEmpty);
  });

  test('AacWord with a note role is musical', () {
    const word = AacWord(
      id: 'i',
      label: 'I',
      row: 1,
      col: 0,
      tags: ['pronoun'],
      musicalRole: MusicalRole.note(0),
    );
    expect(word.isMusical, isTrue);
    expect(word.musicalRole!.kind, MusicalRoleKind.note);
    expect(word.musicalRole!.degree, 0);
    expect(word.tags, ['pronoun']);
  });

  test('chord role carries voice count', () {
    const role = MusicalRole.chord(0, voices: 3);
    expect(role.kind, MusicalRoleKind.chord);
    expect(role.voices, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/aac_music_demo/word_model_test.dart`
Expected: FAIL — symbols not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/features/aac_music_demo/domain/word_model.dart
//
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/aac_music_demo/word_model_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/aac_music_demo/domain/word_model.dart test/features/aac_music_demo/word_model_test.dart
git commit -m "feat(aac): add word model with optional musical role"
```

---

## Task 3: Consonance engine

**Files:**
- Create: `lib/src/features/aac_music_demo/domain/consonance_engine.dart`
- Test: `test/features/aac_music_demo/consonance_engine_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/aac_music_demo/consonance_engine_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/aac_music_demo/consonance_engine_test.dart`
Expected: FAIL — `ConsonanceEngine` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/features/aac_music_demo/domain/consonance_engine.dart
//
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/aac_music_demo/consonance_engine_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/aac_music_demo/domain/consonance_engine.dart test/features/aac_music_demo/consonance_engine_test.dart
git commit -m "feat(aac): add consonance engine (resolve, deClash, bloomChord)"
```

---

## Task 4: Role resolver (hybrid tag-default + override)

**Files:**
- Create: `lib/src/features/aac_music_demo/domain/role_resolver.dart`
- Test: `test/features/aac_music_demo/role_resolver_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/aac_music_demo/role_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/word_model.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/role_resolver.dart';

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/aac_music_demo/role_resolver_test.dart`
Expected: FAIL — `RoleResolver` / `BoardMusicConfig` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/features/aac_music_demo/domain/role_resolver.dart
//
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/aac_music_demo/role_resolver_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/aac_music_demo/domain/role_resolver.dart test/features/aac_music_demo/role_resolver_test.dart
git commit -m "feat(aac): add hybrid role resolver (override -> tag default)"
```

---

## Task 5: Sequencer with speech/audio interfaces

**Files:**
- Create: `lib/src/features/aac_music_demo/domain/sequencer.dart`
- Test: `test/features/aac_music_demo/sequencer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/aac_music_demo/sequencer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/music_theory.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/word_model.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/consonance_engine.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/role_resolver.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/sequencer.dart';

class _Event {
  _Event.speak(this.text) : pitches = null, gain = null;
  _Event.music(this.pitches, this.gain) : text = null;
  final String? text;
  final List<int>? pitches;
  final double? gain;
}

class FakeSpeechSynth implements SpeechSynth {
  final events = <_Event>[];
  @override
  Future<void> speak(String text) async => events.add(_Event.speak(text));
}

class FakeAudioBackend implements AudioBackend {
  final events = <_Event>[];
  @override
  Future<void> warmUp() async {}
  @override
  Future<void> playPitches(List<Pitch> pitches, double gain) async =>
      events.add(_Event.music(pitches.map((p) => p.midi).toList(), gain));
}

void main() {
  const palette = HarmonicPalette(root: PitchClass.c, scale: Scale.majorPentatonic);
  const engine = ConsonanceEngine(palette);
  const resolver = RoleResolver(BoardMusicConfig());

  const i = AacWord(id: 'i', label: 'I', row: 0, col: 0, musicalRole: MusicalRole.note(0));
  const want = AacWord(id: 'want', label: 'want', row: 0, col: 1, musicalRole: MusicalRole.note(3));
  const more = AacWord(id: 'more', label: 'more', row: 0, col: 2, musicalRole: MusicalRole.note(4));

  UtteranceSequencer build(SequencerConfig config, FakeSpeechSynth s, FakeAudioBackend a) =>
      UtteranceSequencer(speech: s, backend: a, engine: engine, resolver: resolver, config: config);

  test('tapAndPhrase: tap speaks the word and plays a gain-clamped note', () async {
    final s = FakeSpeechSynth();
    final a = FakeAudioBackend();
    final seq = build(const SequencerConfig(mode: MusicMode.tapAndPhrase), s, a);

    await seq.onWordSelected(i);

    expect(s.events.single.text, 'I');
    expect(a.events.single.pitches, [60]);
    expect(a.events.single.gain! <= 0.6, isTrue); // under musicHeadroom
  });

  test('phraseOnly: tap speaks but does NOT play music on tap', () async {
    final s = FakeSpeechSynth();
    final a = FakeAudioBackend();
    final seq = build(const SequencerConfig(mode: MusicMode.phraseOnly), s, a);

    await seq.onWordSelected(i);

    expect(s.events.single.text, 'I');
    expect(a.events, isEmpty);
  });

  test('off: no music ever', () async {
    final s = FakeSpeechSynth();
    final a = FakeAudioBackend();
    final seq = build(const SequencerConfig(mode: MusicMode.off), s, a);
    await seq.onWordSelected(i);
    await seq.onSend();
    expect(a.events, isEmpty);
  });

  test('onSend speaks full sentence first (toggle ON) then blooms for 2+ words', () async {
    final s = FakeSpeechSynth();
    final a = FakeAudioBackend();
    final seq = build(
      const SequencerConfig(mode: MusicMode.phraseOnly, speakSentenceOnSend: true, stepMs: 0),
      s, a,
    );
    await seq.onWordSelected(i);
    await seq.onWordSelected(want);
    await seq.onWordSelected(more);
    s.events.clear();
    a.events.clear();

    await seq.onSend();

    // Full sentence spoken first.
    expect(s.events.first.text, 'I want more');
    // Then a per-word melody (3 notes) and a final bloom chord (>=2 pitches).
    final musicEvents = a.events;
    expect(musicEvents.length, 4); // 3 notes + 1 bloom
    expect(musicEvents.last.pitches!.length >= 2, isTrue);
  });

  test('all music gains are clamped under musicHeadroom', () async {
    final s = FakeSpeechSynth();
    final a = FakeAudioBackend();
    final seq = build(
      const SequencerConfig(mode: MusicMode.tapAndPhrase, musicHeadroom: 0.5),
      s, a,
    );
    await seq.onWordSelected(i);
    expect(a.events.single.gain! <= 0.5, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/aac_music_demo/sequencer_test.dart`
Expected: FAIL — `SpeechSynth` / `AudioBackend` / `UtteranceSequencer` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/features/aac_music_demo/domain/sequencer.dart
//
// Turns a built utterance into speech + a musical phrase. The sacred rule:
// speech is the communication and is never suppressed by music; every music
// gain passes through a headroom multiplier so it can't reach speech level.

import 'dart:async';

import 'consonance_engine.dart';
import 'music_theory.dart';
import 'role_resolver.dart';
import 'word_model.dart';

/// Speech engine abstraction. MVP impl wraps the vendored flutter_tts.
abstract class SpeechSynth {
  Future<void> speak(String text);
}

/// Music engine abstraction. MVP impl wraps flutter_midi_pro.
abstract class AudioBackend {
  /// Quiet note on mount so the first real note isn't janky.
  Future<void> warmUp();
  Future<void> playPitches(List<Pitch> pitches, double gain);
}

enum MusicMode { off, phraseOnly, tapAndPhrase }

class SequencerConfig {
  const SequencerConfig({
    this.mode = MusicMode.tapAndPhrase,
    this.musicHeadroom = 0.6,
    this.stepMs = 380,
    this.bloomOnSend = true,
    this.speakSentenceOnSend = true,
  });

  final MusicMode mode;

  /// Hard ceiling on music gain relative to speech.
  final double musicHeadroom;

  /// Delay between notes in the onSend progression.
  final int stepMs;

  /// Finish an onSend phrase with a stacked bloom chord (2+ musical words).
  final bool bloomOnSend;

  /// Speak the full sentence (TTS) when sent. Default ON (AAC norm).
  final bool speakSentenceOnSend;
}

class UtteranceSequencer {
  UtteranceSequencer({
    required this.speech,
    required this.backend,
    required this.engine,
    required this.resolver,
    this.config = const SequencerConfig(),
  });

  final SpeechSynth speech;
  final AudioBackend backend;
  final ConsonanceEngine engine;
  final RoleResolver resolver;
  SequencerConfig config;

  final List<AacWord> _utterance = [];
  List<AacWord> get utterance => List.unmodifiable(_utterance);

  /// SPEAK FIRST (parallel), then — only in tapAndPhrase — an immediate note.
  Future<void> onWordSelected(AacWord word) async {
    _utterance.add(word);

    // Communication. Always. Fire-and-forget so the note isn't gated on TTS.
    unawaited(speech.speak(word.label));

    if (config.mode == MusicMode.tapAndPhrase) {
      final role = resolver.resolveRole(word);
      if (role != null) {
        final v = engine.resolve(role);
        unawaited(backend.playPitches(v.pitches, _clampedGain(v.gain)));
      }
    }
  }

  /// Finalize the utterance: optionally speak the full sentence, then play the
  /// musical recap + bloom (phraseOnly + tapAndPhrase). 'off' does nothing.
  Future<void> onSend() async {
    if (config.mode == MusicMode.off) return;

    if (config.speakSentenceOnSend && _utterance.isNotEmpty) {
      final sentence = _utterance.map((w) => w.label).join(' ');
      await speech.speak(sentence);
    }

    await _playProgression();
  }

  Future<void> _playProgression() async {
    final resolved = <ResolvedVoice>[];
    for (final word in _utterance) {
      final role = resolver.resolveRole(word);
      if (role == null) continue;
      final v = engine.resolve(role);
      resolved.add(v);
      await backend.playPitches(v.pitches, _clampedGain(v.gain));
      if (config.stepMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: config.stepMs));
      }
    }

    if (config.bloomOnSend && resolved.length >= 2) {
      final chord = engine.bloomChord(resolved);
      await backend.playPitches(chord, _clampedGain(0.55));
    }
  }

  void clear() => _utterance.clear();

  double _clampedGain(double raw) =>
      (raw * config.musicHeadroom).clamp(0.0, config.musicHeadroom);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/aac_music_demo/sequencer_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/aac_music_demo/domain/sequencer.dart test/features/aac_music_demo/sequencer_test.dart
git commit -m "feat(aac): add utterance sequencer with speech-first + gain headroom"
```

---

## Task 6: Board model + JSON loader

**Files:**
- Create: `lib/src/features/aac_music_demo/data/aac_board.dart`
- Create: `lib/src/features/aac_music_demo/data/aac_board_loader.dart`
- Create: `assets/aac/demo_board.json`
- Modify: `pubspec.yaml` (add `assets/aac/` to flutter.assets)
- Test: `test/features/aac_music_demo/aac_board_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/aac_music_demo/aac_board_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/music_theory.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/word_model.dart';
import 'package:storia_kids/src/features/aac_music_demo/data/aac_board.dart';

void main() {
  const json = '''
  {
    "palette": {"root": "c", "scale": "majorPentatonic", "baseOctave": 4},
    "tagDefaults": {"pronoun": {"kind": "note", "degree": 0}},
    "words": [
      {"id": "i", "label": "I", "row": 0, "col": 0, "tags": ["pronoun"]},
      {"id": "want", "label": "want", "row": 0, "col": 1,
       "musicalRole": {"kind": "note", "degree": 3}},
      {"id": "go", "label": "go", "row": 0, "col": 2}
    ]
  }
  ''';

  test('parses palette, tag defaults, and words from JSON', () {
    final board = AacBoard.fromJsonString(json);

    expect(board.palette.root, PitchClass.c);
    expect(board.palette.scale, Scale.majorPentatonic);
    expect(board.musicConfig.tagDefaults['pronoun']!.degree, 0);

    expect(board.words.length, 3);
    expect(board.words[0].tags, ['pronoun']);
    expect(board.words[0].musicalRole, isNull); // tag-driven, not override
    expect(board.words[1].musicalRole!.kind, MusicalRoleKind.note);
    expect(board.words[1].musicalRole!.degree, 3);
    expect(board.words[2].isMusical, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/aac_music_demo/aac_board_test.dart`
Expected: FAIL — `AacBoard` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/features/aac_music_demo/data/aac_board.dart
//
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
```

```dart
// lib/src/features/aac_music_demo/data/aac_board_loader.dart
import 'package:flutter/services.dart' show rootBundle;

import 'aac_board.dart';

class AacBoardLoader {
  const AacBoardLoader({this.assetPath = 'assets/aac/demo_board.json'});
  final String assetPath;

  Future<AacBoard> load() async {
    final source = await rootBundle.loadString(assetPath);
    return AacBoard.fromJsonString(source);
  }
}
```

```json
// assets/aac/demo_board.json
{
  "palette": { "root": "c", "scale": "majorPentatonic", "baseOctave": 4 },
  "tagDefaults": {
    "pronoun": { "kind": "note", "degree": 0 },
    "request": { "kind": "note", "degree": 3 },
    "quantity": { "kind": "note", "degree": 4 }
  },
  "words": [
    { "id": "i", "label": "I", "row": 0, "col": 0, "tags": ["pronoun"] },
    { "id": "want", "label": "want", "row": 0, "col": 1, "tags": ["request"] },
    { "id": "more", "label": "more", "row": 0, "col": 2, "tags": ["quantity"] },
    { "id": "help", "label": "help", "row": 0, "col": 3, "musicalRole": { "kind": "note", "degree": 2 } },
    { "id": "yes", "label": "yes", "row": 1, "col": 0, "musicalRole": { "kind": "note", "degree": 1 } },
    { "id": "no", "label": "no", "row": 1, "col": 1 },
    { "id": "go", "label": "go", "row": 1, "col": 2 },
    { "id": "stop", "label": "stop", "row": 1, "col": 3 }
  ]
}
```

Add `assets/aac/` to `pubspec.yaml` under `flutter.assets` (alongside the existing entries):

```yaml
  assets:
    - .env
    - assets/gifs/
    - assets/svgs/
    - assets/images/
    - assets/tiles/
    - assets/aac/
```

- [ ] **Step 4: Run test + analyze to verify**

Run: `flutter test test/features/aac_music_demo/aac_board_test.dart`
Expected: PASS (1 test).
Run: `flutter pub get && flutter analyze`
Expected: exit 0, no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/aac_music_demo/data/ assets/aac/demo_board.json pubspec.yaml test/features/aac_music_demo/aac_board_test.dart
git commit -m "feat(aac): add board JSON model, loader, and demo vocabulary asset"
```

---

## Task 7: Flutter TTS speech adapter

**Files:**
- Create: `lib/src/features/aac_music_demo/adapters/flutter_tts_speech_synth.dart`
- Verify against: `third_party/flutter_tts/lib/flutter_tts.dart` (confirm `speak`, `setVolume`, `awaitSpeakCompletion` signatures).

This adapter is a thin wrapper over a plugin; it is verified by `flutter analyze` and manual run, not a unit test (no value in mocking the plugin here).

- [ ] **Step 1: Confirm the plugin API**

Run: `grep -nE 'Future.*(speak|setVolume|setSpeechRate|setPitch|awaitSpeakCompletion)' third_party/flutter_tts/lib/flutter_tts.dart`
Expected: method signatures present. Adjust the implementation below if names differ.

- [ ] **Step 2: Write the adapter**

```dart
// lib/src/features/aac_music_demo/adapters/flutter_tts_speech_synth.dart
//
// SpeechSynth backed by the vendored flutter_tts. Configured once for a calm,
// child-friendly voice. speak() does not block the caller (music fires in
// parallel per the sequencer's timing decision).

import 'package:flutter_tts/flutter_tts.dart';

import '../domain/sequencer.dart';

class FlutterTtsSpeechSynth implements SpeechSynth {
  FlutterTtsSpeechSynth([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.setVolume(1.0); // speech is the function — full level
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _configured = true;
  }

  @override
  Future<void> speak(String text) async {
    await _ensureConfigured();
    await _tts.stop(); // interrupt any in-flight utterance for snappy taps
    await _tts.speak(text);
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/src/features/aac_music_demo/adapters/flutter_tts_speech_synth.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/src/features/aac_music_demo/adapters/flutter_tts_speech_synth.dart
git commit -m "feat(aac): add flutter_tts speech adapter"
```

---

## Task 8: MIDI audio backend

**Files:**
- Modify: `pubspec.yaml` (add `flutter_midi_pro`)
- Add: a soft soundfont at `assets/aac/soundfonts/<name>.sf2` + register `assets/aac/soundfonts/` in `pubspec.yaml`
- Create: `lib/src/features/aac_music_demo/adapters/midi_audio_backend.dart`
- Verify against the installed `flutter_midi_pro` README for exact method signatures.

- [ ] **Step 1: Add the dependency and soundfont**

```bash
flutter pub add flutter_midi_pro
```

Place a small, soft General-MIDI-style soundfont (bell / mallet / electric-piano) at `assets/aac/soundfonts/calm.sf2`. Register the folder in `pubspec.yaml`:

```yaml
  assets:
    - .env
    - assets/gifs/
    - assets/svgs/
    - assets/images/
    - assets/tiles/
    - assets/aac/
    - assets/aac/soundfonts/
```

Run: `flutter pub get`
Expected: resolves successfully.

- [ ] **Step 2: Confirm the plugin API**

Open the `flutter_midi_pro` README (pub.dev) and confirm the load/play/stop signatures. As of `flutter_midi_pro` 3.x the surface is:
`MidiPro().loadSoundfont(path:, bank:, program:)` → `int sfId`; `playNote(channel:, key:, velocity:, sfId:)`; `stopNote(channel:, key:, sfId:)`. Adjust the code below to match the installed version.

- [ ] **Step 3: Write the adapter**

```dart
// lib/src/features/aac_music_demo/adapters/midi_audio_backend.dart
//
// AudioBackend backed by flutter_midi_pro. Loads a soft soundfont, warms up on
// mount, and maps a 0..1 gain to MIDI velocity. Notes auto-release after a
// short sustain so taps don't ring forever.

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';

import '../domain/music_theory.dart';
import '../domain/sequencer.dart';

class MidiAudioBackend implements AudioBackend {
  MidiAudioBackend({
    this.soundfontAsset = 'assets/aac/soundfonts/calm.sf2',
    this.channel = 0,
    this.sustain = const Duration(milliseconds: 900),
  });

  final String soundfontAsset;
  final int channel;
  final Duration sustain;

  final MidiPro _midi = MidiPro();
  int? _sfId;

  Future<int> _ensureLoaded() async {
    final existing = _sfId;
    if (existing != null) return existing;
    final id = await _midi.loadSoundfont(
      path: soundfontAsset,
      bank: 0,
      program: 0,
    );
    _sfId = id;
    return id;
  }

  @override
  Future<void> warmUp() async {
    try {
      final sf = await _ensureLoaded();
      // Near-silent priming note so the first audible note isn't janky.
      await _midi.playNote(channel: channel, key: 60, velocity: 1, sfId: sf);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await _midi.stopNote(channel: channel, key: 60, sfId: sf);
    } catch (e) {
      debugPrint('MidiAudioBackend.warmUp failed: $e');
    }
  }

  @override
  Future<void> playPitches(List<Pitch> pitches, double gain) async {
    try {
      final sf = await _ensureLoaded();
      final velocity = (gain.clamp(0.0, 1.0) * 127).round().clamp(1, 127);
      for (final p in pitches) {
        await _midi.playNote(
          channel: channel,
          key: p.midi,
          velocity: velocity,
          sfId: sf,
        );
      }
      // Auto-release after sustain so notes don't accumulate.
      Future<void>.delayed(sustain, () async {
        for (final p in pitches) {
          await _midi.stopNote(channel: channel, key: p.midi, sfId: sf);
        }
      });
    } catch (e) {
      debugPrint('MidiAudioBackend.playPitches failed: $e');
    }
  }
}

// The Uint8List import is reserved for future sample-based fallback; kept to
// document the abstraction boundary. Remove if unused after the spike.
// ignore: unused_element
typedef _Reserved = Uint8List;
```

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/src/features/aac_music_demo/adapters/midi_audio_backend.dart`
Expected: No issues. (If `_Reserved`/`Uint8List` trips a lint, delete those two lines and the `dart:typed_data` import.)

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/features/aac_music_demo/adapters/midi_audio_backend.dart assets/aac/soundfonts/
git commit -m "feat(aac): add flutter_midi_pro audio backend with warm-up"
```

---

## Task 9: Demo controller (Riverpod)

**Files:**
- Create: `lib/src/features/aac_music_demo/presentation/aac_music_demo_controller.dart`
- Test: `test/features/aac_music_demo/aac_music_demo_controller_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/aac_music_demo/aac_music_demo_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/music_theory.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/word_model.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/consonance_engine.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/role_resolver.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/sequencer.dart';
import 'package:storia_kids/src/features/aac_music_demo/data/aac_board.dart';
import 'package:storia_kids/src/features/aac_music_demo/presentation/aac_music_demo_controller.dart';

class _SilentSpeech implements SpeechSynth {
  @override
  Future<void> speak(String text) async {}
}

class _SilentBackend implements AudioBackend {
  @override
  Future<void> warmUp() async {}
  @override
  Future<void> playPitches(List<Pitch> pitches, double gain) async {}
}

AacMusicDemoController _controller() {
  const board = AacBoard(
    palette: HarmonicPalette(root: PitchClass.c, scale: Scale.majorPentatonic),
    musicConfig: BoardMusicConfig(),
    words: [
      AacWord(id: 'i', label: 'I', row: 0, col: 0, musicalRole: MusicalRole.note(0)),
      AacWord(id: 'more', label: 'more', row: 0, col: 1, musicalRole: MusicalRole.note(4)),
    ],
  );
  final engine = ConsonanceEngine(board.palette);
  final sequencer = UtteranceSequencer(
    speech: _SilentSpeech(),
    backend: _SilentBackend(),
    engine: engine,
    resolver: RoleResolver(board.musicConfig),
  );
  return AacMusicDemoController(board: board, sequencer: sequencer);
}

void main() {
  test('selecting words appends to utterance', () async {
    final c = _controller();
    await c.selectWord(c.state.board.words[0]);
    await c.selectWord(c.state.board.words[1]);
    expect(c.state.utteranceLabels, ['I', 'more']);
  });

  test('clear empties the utterance', () async {
    final c = _controller();
    await c.selectWord(c.state.board.words[0]);
    c.clearUtterance();
    expect(c.state.utteranceLabels, isEmpty);
  });

  test('changing mode updates state and sequencer config', () async {
    final c = _controller();
    c.setMode(MusicMode.phraseOnly);
    expect(c.state.mode, MusicMode.phraseOnly);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/aac_music_demo/aac_music_demo_controller_test.dart`
Expected: FAIL — `AacMusicDemoController` not defined.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/features/aac_music_demo/presentation/aac_music_demo_controller.dart
//
// Riverpod StateNotifier for the demo screen. Owns the utterance, the active
// MusicMode, and bridges UI taps to the sequencer. Hand-written providers
// (no codegen, per repo convention).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adapters/flutter_tts_speech_synth.dart';
import '../adapters/midi_audio_backend.dart';
import '../data/aac_board.dart';
import '../data/aac_board_loader.dart';
import '../domain/consonance_engine.dart';
import '../domain/role_resolver.dart';
import '../domain/sequencer.dart';
import '../domain/word_model.dart';

@immutable
class AacMusicDemoState {
  const AacMusicDemoState({
    required this.board,
    required this.utteranceLabels,
    required this.mode,
  });

  final AacBoard board;
  final List<String> utteranceLabels;
  final MusicMode mode;

  AacMusicDemoState copyWith({
    List<String>? utteranceLabels,
    MusicMode? mode,
  }) {
    return AacMusicDemoState(
      board: board,
      utteranceLabels: utteranceLabels ?? this.utteranceLabels,
      mode: mode ?? this.mode,
    );
  }
}

class AacMusicDemoController extends StateNotifier<AacMusicDemoState> {
  AacMusicDemoController({
    required AacBoard board,
    required UtteranceSequencer sequencer,
  })  : _sequencer = sequencer,
        super(AacMusicDemoState(
          board: board,
          utteranceLabels: const [],
          mode: sequencer.config.mode,
        ));

  final UtteranceSequencer _sequencer;

  Future<void> warmUp() => _sequencer.backend.warmUp();

  Future<void> selectWord(AacWord word) async {
    await _sequencer.onWordSelected(word);
    state = state.copyWith(
      utteranceLabels: _sequencer.utterance.map((w) => w.label).toList(),
    );
  }

  Future<void> send() => _sequencer.onSend();

  void clearUtterance() {
    _sequencer.clear();
    state = state.copyWith(utteranceLabels: const []);
  }

  void setMode(MusicMode mode) {
    _sequencer.config = SequencerConfig(
      mode: mode,
      musicHeadroom: _sequencer.config.musicHeadroom,
      stepMs: _sequencer.config.stepMs,
      bloomOnSend: _sequencer.config.bloomOnSend,
      speakSentenceOnSend: _sequencer.config.speakSentenceOnSend,
    );
    state = state.copyWith(mode: mode);
  }
}

/// Async provider that loads the board, builds the sequencer with real
/// adapters, and exposes the controller. The demo screen watches this.
final aacMusicDemoControllerProvider = FutureProvider.autoDispose<
    AacMusicDemoController>((ref) async {
  final board = await const AacBoardLoader().load();
  final sequencer = UtteranceSequencer(
    speech: FlutterTtsSpeechSynth(),
    backend: MidiAudioBackend(),
    engine: ConsonanceEngine(board.palette),
    resolver: RoleResolver(board.musicConfig),
  );
  final controller = AacMusicDemoController(board: board, sequencer: sequencer);
  await controller.warmUp();
  return controller;
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/aac_music_demo/aac_music_demo_controller_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/src/features/aac_music_demo/presentation/aac_music_demo_controller.dart test/features/aac_music_demo/aac_music_demo_controller_test.dart
git commit -m "feat(aac): add Riverpod demo controller bridging UI to sequencer"
```

---

## Task 10: Demo screen (board UI)

**Files:**
- Modify: `lib/src/features/aac_music_demo/presentation/aac_music_demo_screen.dart` (move from current path `lib/src/features/aac_music_demo/aac_music_demo_screen.dart` into `presentation/` and replace the placeholder)
- Modify: `lib/src/routing/app_router.dart` (update import path)
- Test: `test/features/aac_music_demo/aac_music_demo_screen_test.dart`

- [ ] **Step 1: Move the existing file and update the route import**

```bash
mkdir -p lib/src/features/aac_music_demo/presentation
git mv lib/src/features/aac_music_demo/aac_music_demo_screen.dart \
       lib/src/features/aac_music_demo/presentation/aac_music_demo_screen.dart
```

In `lib/src/routing/app_router.dart`, change the import:

```dart
import '../features/aac_music_demo/presentation/aac_music_demo_screen.dart';
```

- [ ] **Step 2: Write the failing test**

```dart
// test/features/aac_music_demo/aac_music_demo_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/music_theory.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/word_model.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/consonance_engine.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/role_resolver.dart';
import 'package:storia_kids/src/features/aac_music_demo/domain/sequencer.dart';
import 'package:storia_kids/src/features/aac_music_demo/data/aac_board.dart';
import 'package:storia_kids/src/features/aac_music_demo/presentation/aac_music_demo_controller.dart';
import 'package:storia_kids/src/features/aac_music_demo/presentation/aac_music_demo_screen.dart';

class _SilentSpeech implements SpeechSynth {
  @override
  Future<void> speak(String text) async {}
}

class _SilentBackend implements AudioBackend {
  @override
  Future<void> warmUp() async {}
  @override
  Future<void> playPitches(List<Pitch> pitches, double gain) async {}
}

AacMusicDemoController _fakeController() {
  const board = AacBoard(
    palette: HarmonicPalette(root: PitchClass.c, scale: Scale.majorPentatonic),
    musicConfig: BoardMusicConfig(),
    words: [
      AacWord(id: 'i', label: 'I', row: 0, col: 0, musicalRole: MusicalRole.note(0)),
      AacWord(id: 'want', label: 'want', row: 0, col: 1, musicalRole: MusicalRole.note(3)),
      AacWord(id: 'more', label: 'more', row: 0, col: 2, musicalRole: MusicalRole.note(4)),
    ],
  );
  return AacMusicDemoController(
    board: board,
    sequencer: UtteranceSequencer(
      speech: _SilentSpeech(),
      backend: _SilentBackend(),
      engine: ConsonanceEngine(board.palette),
      resolver: RoleResolver(board.musicConfig),
    ),
  );
}

void main() {
  testWidgets('renders board words and builds an utterance on tap', (tester) async {
    final controller = _fakeController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aacMusicDemoControllerProvider.overrideWith((ref) async => controller),
        ],
        child: const MaterialApp(home: AacMusicDemoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ElevatedButton, 'I'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'I'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'want'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'more'));
    await tester.pump();

    expect(find.text('I want more'), findsOneWidget);
  });

  testWidgets('clear empties the sentence strip', (tester) async {
    final controller = _fakeController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aacMusicDemoControllerProvider.overrideWith((ref) async => controller),
        ],
        child: const MaterialApp(home: AacMusicDemoScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'I'));
    await tester.pump();
    await tester.tap(find.byTooltip('Clear sentence'));
    await tester.pump();

    expect(find.text('I'), findsOneWidget); // still on the board button
    expect(find.text('I want more'), findsNothing);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/aac_music_demo/aac_music_demo_screen_test.dart`
Expected: FAIL — screen still the placeholder; no board buttons / sentence strip.

- [ ] **Step 4: Replace the screen implementation**

```dart
// lib/src/features/aac_music_demo/presentation/aac_music_demo_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/storia_colors.dart';
import '../../../core/theme/storia_spacing.dart';
import '../../../core/widgets/sketch_card.dart';
import '../domain/sequencer.dart';
import '../domain/word_model.dart';
import 'aac_music_demo_controller.dart';

class AacMusicDemoScreen extends ConsumerWidget {
  const AacMusicDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(aacMusicDemoControllerProvider);
    return Scaffold(
      backgroundColor: StoriaColors.paper,
      appBar: AppBar(
        backgroundColor: StoriaColors.paper,
        foregroundColor: StoriaColors.ink,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to library',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('AAC Music Demo'),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load board: $e')),
          data: (controller) => _DemoBody(controller: controller),
        ),
      ),
    );
  }
}

class _DemoBody extends StatefulWidget {
  const _DemoBody({required this.controller});
  final AacMusicDemoController controller;

  @override
  State<_DemoBody> createState() => _DemoBodyState();
}

class _DemoBodyState extends State<_DemoBody> {
  AacMusicDemoController get _c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final state = _c.state;
        final sentence = state.utteranceLabels.join(' ');
        return Padding(
          padding: const EdgeInsets.all(StoriaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SketchCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        sentence.isEmpty ? 'Tap words to build a sentence' : sentence,
                        style: textTheme.titleLarge?.copyWith(
                          color: StoriaColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear sentence',
                      icon: const Icon(Icons.backspace_outlined),
                      onPressed: _c.clearUtterance,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: StoriaSpacing.lg),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: StoriaSpacing.sm,
                  crossAxisSpacing: StoriaSpacing.sm,
                  childAspectRatio: 1.4,
                  children: [
                    for (final word in state.board.words)
                      ElevatedButton(
                        onPressed: () => _c.selectWord(word),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StoriaColors.paperRaised,
                          foregroundColor: StoriaColors.ink,
                        ),
                        child: Text(word.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: StoriaSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<MusicMode>(
                      segments: const [
                        ButtonSegment(value: MusicMode.off, label: Text('Off')),
                        ButtonSegment(value: MusicMode.phraseOnly, label: Text('Phrase')),
                        ButtonSegment(value: MusicMode.tapAndPhrase, label: Text('Tap+Phrase')),
                      ],
                      selected: {state.mode},
                      onSelectionChanged: (s) => _c.setMode(s.first),
                    ),
                  ),
                  const SizedBox(width: StoriaSpacing.sm),
                  FilledButton.icon(
                    onPressed: _c.send,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Speak + Play'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/aac_music_demo/aac_music_demo_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/src/features/aac_music_demo/presentation/aac_music_demo_screen.dart lib/src/routing/app_router.dart test/features/aac_music_demo/aac_music_demo_screen_test.dart
git commit -m "feat(aac): build demo board screen wired to controller"
```

---

## Task 11: Full verification + UI proof

**Files:** none (verification only)

- [ ] **Step 1: Run the full gate**

Run: `./bin/verify.sh`
Expected: `flutter analyze` → no issues; `flutter test` → all pass (including the existing Library navigation test from the scaffold commit).

- [ ] **Step 2: Capture Playwright UI proof** (UI-verifiable ticket)

Per `AGENTS.md`, record the App Review flow into the demo:

```bash
flutter run -d chrome &
mkdir -p recordings
playwright-cli open <chrome-app-url>
playwright-cli video-start
# Start your journey -> app-review@storia.kids -> birth year 1980 -> onboarding -> library
# tap the music-note button -> tap I / want / more -> press "Speak + Play"
playwright-cli video-stop --filename=recordings/aac-music-demo-proof.webm
playwright-cli close
```

Record the artifact path in the Linear workpad and PR.

- [ ] **Step 3: Final commit (if any housekeeping)**

```bash
git add -A
git commit -m "chore(aac): verification pass for musical utterances demo" || echo "nothing to commit"
```

---

## Self-Review

**Spec coverage:**
- Consonance-by-construction → Tasks 1, 3. ✅
- Scale-degree storage / realm independence → Tasks 1, 2. ✅
- Hybrid tag-default + override → Task 4. ✅
- Modes off/phraseOnly/tapAndPhrase, parallel+gain-ducked tap (#2 = B) → Task 5. ✅
- Speak-sentence-on-send default ON (#3 = C) → Task 5. ✅
- Mode + utterance-length bloom; no per-user progression (#4 = A+B) → Tasks 4, 5. ✅
- JSON asset storage → Task 6. ✅
- flutter_tts MVP behind SpeechSynth (engine decision A) → Tasks 5, 7. ✅
- flutter_midi_pro + warm-up, AudioBackend abstraction (#1 = A) → Tasks 5, 8. ✅
- Minimal demo scope (#5 = A): no motifs/icons/realms/expressive in UI → Tasks 6, 10. ✅
- Standalone /aac-music-demo route + Library button → already scaffolded; Task 10 updates import. ✅
- sherpa_onnx spike → out of scope here, documented in spec §6/§7. ✅ (no task by design)

**Placeholder scan:** No TBD/TODO. External-plugin API steps (Tasks 7, 8) include concrete code plus an explicit "confirm signatures against installed version" step — not placeholders.

**Type consistency:** `SpeechSynth.speak`, `AudioBackend.warmUp`/`playPitches`, `MusicalRole`/`MusicalRoleKind`, `BoardMusicConfig.tagDefaults`, `RoleResolver.resolveRole`, `UtteranceSequencer.onWordSelected`/`onSend`/`clear`/`config`/`utterance`, `AacBoard.fromJsonString`, `AacMusicDemoController.selectWord`/`send`/`clearUtterance`/`setMode`/`state` are used consistently across tasks and tests.
