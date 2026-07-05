import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/reader/reader_tilt.dart';

void main() {
  group('ReaderTiltNormalizer', () {
    const normalizer = ReaderTiltNormalizer(maxOffset: 4, smoothing: 1);

    test('clamps accelerometer input to max offsets', () {
      expect(normalizer.normalize(x: -100, y: 100), const Offset(4, 4));
      expect(normalizer.normalize(x: 100, y: -100), const Offset(-4, -4));
    });

    test('maps small movement proportionally', () {
      final tilt = normalizer.normalize(x: -4.9, y: 2.45);

      expect(tilt.dx, closeTo(2, 0.001));
      expect(tilt.dy, closeTo(1, 0.001));
    });
  });
}
