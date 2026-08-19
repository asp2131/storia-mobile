import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Mic capture behind a thin port so the controller is testable without
/// platform channels.
abstract interface class NarrationRecorder {
  Future<bool> hasPermission();

  /// Begins capture; returns the file being written.
  Future<File> start(String fileNameHint);

  /// Stops capture and returns the finished file (null if nothing was written).
  Future<File?> stop();

  Future<void> cancel();

  Future<void> dispose();
}

class RecordNarrationRecorder implements NarrationRecorder {
  RecordNarrationRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  File? _current;

  /// AAC-LC in an m4a container: small uploads, plays in just_audio on both
  /// platforms, and is accepted by the API's audio type allowlist.
  static const RecordConfig _config = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 64000,
    sampleRate: 44100,
    numChannels: 1,
  );

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<File> start(String fileNameHint) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      p.join(
        directory.path,
        'narration_${fileNameHint}_${DateTime.now().millisecondsSinceEpoch}.m4a',
      ),
    );

    await _recorder.start(_config, path: file.path);
    _current = file;
    return file;
  }

  @override
  Future<File?> stop() async {
    final path = await _recorder.stop();
    final file = path != null ? File(path) : _current;
    _current = null;

    if (file == null || !await file.exists()) return null;
    return file;
  }

  @override
  Future<void> cancel() async {
    await _recorder.cancel();
    final file = _current;
    _current = null;
    if (file != null && await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
