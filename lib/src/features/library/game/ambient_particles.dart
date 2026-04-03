import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// A subtle floating-dust particle system for the library scene.
///
/// Renders gentle dust motes that drift slowly upward with a soft wobble,
/// giving the cozy library a lived-in feel. All coordinates are in
/// world-space so particles scroll naturally with the Flame camera.
class AmbientParticlesComponent extends Component {
  AmbientParticlesComponent({
    required this.worldWidth,
    required this.worldHeight,
    this.particleCount = 18,
  });

  final double worldWidth;
  final double worldHeight;
  final int particleCount;

  final List<_DustMote> _motes = [];
  final Random _rng = Random();

  static const Color _baseColor = Color(0xFFD4B896); // warm dust tone

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (var i = 0; i < particleCount; i++) {
      _motes.add(_spawnMote(randomizeY: true));
    }
  }

  _DustMote _spawnMote({required bool randomizeY}) {
    return _DustMote(
      x: _rng.nextDouble() * worldWidth,
      y: randomizeY
          ? _rng.nextDouble() * worldHeight
          : worldHeight + _rng.nextDouble() * 40,
      size: 2.0 + _rng.nextDouble() * 3.0, // 2-5 px
      opacity: 0.1 + _rng.nextDouble() * 0.3, // 0.1-0.4
      driftSpeed: 6.0 + _rng.nextDouble() * 10.0, // px/s upward
      wobbleSpeed: 0.4 + _rng.nextDouble() * 0.8,
      wobbleAmplitude: 4.0 + _rng.nextDouble() * 8.0,
      phase: _rng.nextDouble() * 2 * pi,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (var i = 0; i < _motes.length; i++) {
      final m = _motes[i];
      m.phase += m.wobbleSpeed * dt;
      m.y -= m.driftSpeed * dt;
      m.x += sin(m.phase) * m.wobbleAmplitude * dt;

      // Wrap when the mote drifts above the visible area.
      if (m.y < -10) {
        _motes[i] = _spawnMote(randomizeY: false);
        _motes[i].y = worldHeight + _rng.nextDouble() * 20;
      }

      // Horizontal wrap.
      if (m.x < -10) {
        m.x = worldWidth + 5;
      } else if (m.x > worldWidth + 10) {
        m.x = -5;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    for (final m in _motes) {
      final paint = Paint()
        ..color = _baseColor.withValues(alpha: m.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(m.x, m.y), m.size / 2, paint);
    }
  }
}

class _DustMote {
  _DustMote({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.driftSpeed,
    required this.wobbleSpeed,
    required this.wobbleAmplitude,
    required this.phase,
  });

  double x;
  double y;
  double size;
  double opacity;
  double driftSpeed;
  double wobbleSpeed;
  double wobbleAmplitude;
  double phase;
}
