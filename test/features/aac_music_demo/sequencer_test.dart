import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/aac_music_demo/domain/music_theory.dart';
import 'package:loratone/src/features/aac_music_demo/domain/word_model.dart';
import 'package:loratone/src/features/aac_music_demo/domain/consonance_engine.dart';
import 'package:loratone/src/features/aac_music_demo/domain/role_resolver.dart';
import 'package:loratone/src/features/aac_music_demo/domain/sequencer.dart';

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
