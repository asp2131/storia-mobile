import '../ports/speech_practice_port.dart';

/// Sample reading has no microphone capability and never constructs a plugin.
class DisabledSpeechPracticePort implements SpeechPracticePort {
  const DisabledSpeechPracticePort();

  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> startListening({
    required void Function(String recognizedWords, {required bool isFinal})
    onResult,
    required void Function() onDone,
    required void Function(Object error) onError,
  }) async {
    onError(
      UnsupportedError('Speech practice is unavailable in sample reading.'),
    );
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> dispose() async {}
}
