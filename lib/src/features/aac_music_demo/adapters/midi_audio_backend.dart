// lib/src/features/aac_music_demo/adapters/midi_audio_backend.dart
//
// AudioBackend backed by flutter_midi_pro. Loads a soft soundfont, warms up on
// mount, and maps a 0..1 gain to MIDI velocity. Notes auto-release after a
// short sustain so taps don't ring forever.
//
// API note: flutter_midi_pro 3.1.6 exposes `loadSoundfontAsset(assetPath:)`
// (returns the sfId) rather than the `loadSoundfont(path:)` named in the plan;
// `playNote`/`stopNote` match the planned named-parameter surface.

import 'package:flutter/foundation.dart';
import 'package:flutter_midi_pro/flutter_midi_pro.dart';

import '../domain/music_theory.dart';
import '../domain/sequencer.dart';

class MidiAudioBackend implements AudioBackend {
  MidiAudioBackend({
    this.soundfontAsset = 'assets/aac/soundfonts/soundfont.sf2',
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
    final id = await _midi.loadSoundfontAsset(
      assetPath: soundfontAsset,
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
