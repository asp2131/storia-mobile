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
