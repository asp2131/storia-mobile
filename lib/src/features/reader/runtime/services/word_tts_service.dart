import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class WordTtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  Completer<void>? _speakCompleter;

  /// Initialize TTS engine with kid-friendly settings.
  /// Rate 0.45, pitch 1.1.
  /// Locale: detect device locale — use en-GB/Commonwealth variants when present, otherwise en-US.
  Future<void> init() async {
    if (_initialized) return;

    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.1);
    await _tts.setVolume(1.0);

    // Detect locale: prefer Commonwealth English if device is set to it
    final locale = Platform.localeName; // e.g. "en_GB", "en_US"
    final lang = _resolveEnglishLocale(locale);
    await _tts.setLanguage(lang);

    _tts.setCompletionHandler(() {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });

    _tts.setCancelHandler(() {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });

    _tts.setErrorHandler((msg) {
      _speakCompleter?.complete();
      _speakCompleter = null;
    });

    _initialized = true;
  }

  /// Speak a single word. Returns a Future that completes when TTS finishes or is cancelled.
  /// If called while already speaking, stops the current utterance first (interrupt behavior).
  Future<void> speak(String word) async {
    await init();
    // Cancel any in-progress speech
    await stop();

    _speakCompleter = Completer<void>();
    await _tts.speak(word);
    return _speakCompleter!.future;
  }

  /// Stop any current speech immediately.
  Future<void> stop() async {
    _speakCompleter?.complete();
    _speakCompleter = null;
    await _tts.stop();
  }

  /// Resolve English locale variant. Commonwealth English locales use their native variant.
  String _resolveEnglishLocale(String platformLocale) {
    final lower = platformLocale.toLowerCase().replaceAll('-', '_');
    const commonwealthPrefixes = [
      'en_gb',
      'en_au',
      'en_nz',
      'en_ie',
      'en_za',
    ];
    for (final prefix in commonwealthPrefixes) {
      if (lower.startsWith(prefix)) {
        // Return in format TTS expects: "en-GB" etc.
        return '${prefix.substring(0, 2)}-${prefix.substring(3).toUpperCase()}';
      }
    }
    return 'en-US';
  }

  void dispose() {
    stop();
    _tts.stop();
  }
}
