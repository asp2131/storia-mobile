abstract interface class SpeechPracticePort {
  Future<bool> initialize();

  Future<void> startListening({
    required void Function(String recognizedWords, {required bool isFinal})
    onResult,
    required void Function() onDone,
    required void Function(Object error) onError,
  });

  Future<void> stopListening();

  Future<void> dispose();
}
