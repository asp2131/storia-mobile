import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/audio/sfx_bus.dart';

void main() {
  test('SfxBus disables playback after backend failure', () async {
    final backend = _ThrowingSfxBackend();
    final bus = SfxBus(backend: backend);

    await bus.wordTap();
    await bus.pageChange();

    expect(backend.played, [SfxCue.wordTap]);
  });

  test('SfxBus dispose swallows backend teardown failure', () async {
    final bus = SfxBus(backend: _ThrowingSfxBackend());

    await bus.dispose();
  });
}

class _ThrowingSfxBackend implements SfxBackend {
  final played = <SfxCue>[];

  @override
  Future<void> play(SfxCue cue) async {
    played.add(cue);
    throw StateError('missing optional sfx asset');
  }

  @override
  Future<void> dispose() async {
    throw StateError('already torn down');
  }
}
