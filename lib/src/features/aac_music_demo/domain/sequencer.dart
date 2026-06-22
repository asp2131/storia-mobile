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
