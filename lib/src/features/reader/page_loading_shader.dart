import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/theme/storia_colors.dart';

/// Animated GLSL fill shown behind a still-loading page illustration. Falls back
/// to a flat color until the shader program finishes loading, so there's never
/// a blank frame.
///
// ponytail: repaints every frame while visible — fine, it's gone the moment the
// picture decodes (a cache hit on most pages). Don't keep it on screen for long.
class PageLoadingShader extends StatefulWidget {
  final bool dark;
  const PageLoadingShader({super.key, required this.dark});

  // Load the program once for the whole app.
  static Future<ui.FragmentProgram>? _programFuture;
  static Future<ui.FragmentProgram> _program() =>
      _programFuture ??= ui.FragmentProgram.fromAsset('shaders/page_loading.frag');

  @override
  State<PageLoadingShader> createState() => _PageLoadingShaderState();
}

class _PageLoadingShaderState extends State<PageLoadingShader>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late final Ticker _ticker;
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      setState(() => _seconds = elapsed.inMicroseconds / 1e6);
    });
    PageLoadingShader._program().then((program) {
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
      _ticker.start();
    }).catchError((_) {
      // Asset unavailable (e.g. headless test) — flat fill is the fallback.
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    super.dispose();
  }

  // Soft brand tints; muted so the loader never out-shouts the artwork.
  List<Color> get _colors => widget.dark
      ? const [Color(0xFF12161A), Color(0xFF22303A), StoriaColors.mustard]
      : const [Color(0xFFDDDDD4), StoriaColors.sage, StoriaColors.mustard];

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) {
      return ColoredBox(color: _colors.first);
    }
    return CustomPaint(
      painter: _ShaderPainter(
        shader: shader,
        time: _seconds,
        colors: _colors,
      ),
      size: Size.infinite,
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final List<Color> colors;

  _ShaderPainter({
    required this.shader,
    required this.time,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time);
    var i = 3;
    for (final c in colors) {
      shader
        ..setFloat(i++, c.r)
        ..setFloat(i++, c.g)
        ..setFloat(i++, c.b);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) => old.time != time;
}
