import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ports/speech_practice_port.dart';

class SpeechToTextPracticePort implements SpeechPracticePort {
  final SpeechToText _speech = SpeechToText();
  void Function()? _onDone;

  @override
  Future<bool> initialize() {
    return _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _onDone?.call();
        }
      },
    );
  }

  @override
  Future<void> startListening({
    required void Function(String recognizedWords, {required bool isFinal})
    onResult,
    required void Function() onDone,
    required void Function(Object error) onError,
  }) async {
    _onDone = onDone;

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          onResult(result.recognizedWords, isFinal: result.finalResult);
        },
        onSoundLevelChange: (_) {},
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
        ),
      );
    } catch (error) {
      onError(error);
    }
  }

  @override
  Future<void> stopListening() => _speech.stop();

  @override
  Future<void> dispose() => _speech.stop();
}
