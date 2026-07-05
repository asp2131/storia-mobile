import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ReaderTiltNormalizer {
  const ReaderTiltNormalizer({this.maxOffset = 4, this.smoothing = 0.18});

  final double maxOffset;
  final double smoothing;

  Offset normalize({
    required double x,
    required double y,
    Offset previous = Offset.zero,
  }) {
    const gravity = 9.8;
    final target = Offset(
      (-x / gravity).clamp(-1.0, 1.0) * maxOffset,
      (y / gravity).clamp(-1.0, 1.0) * maxOffset,
    );
    return Offset.lerp(previous, target, smoothing) ?? target;
  }
}

class ReaderTiltController extends ValueNotifier<Offset> {
  ReaderTiltController({
    ReaderTiltNormalizer normalizer = const ReaderTiltNormalizer(),
  }) : _normalizer = normalizer,
       super(Offset.zero);

  final ReaderTiltNormalizer _normalizer;
  StreamSubscription<AccelerometerEvent>? _subscription;

  void start({bool enabled = true}) {
    if (!enabled || kIsWeb || _subscription != null) return;
    try {
      _subscription =
          accelerometerEventStream(
            samplingPeriod: SensorInterval.normalInterval,
          ).listen(
            (event) => value = _normalizer.normalize(
              x: event.x,
              y: event.y,
              previous: value,
            ),
            onError: (_) => value = Offset.zero,
            cancelOnError: false,
          );
    } catch (_) {
      value = Offset.zero;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
