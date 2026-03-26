import 'package:flutter/material.dart';

@immutable
class OverlayFrame {
  const OverlayFrame({required this.elements, required this.isActive});

  final List<OverlayElementFrame> elements;
  final bool isActive;
}

@immutable
class OverlayElementFrame {
  const OverlayElementFrame({
    required this.left,
    required this.top,
    required this.width,
    required this.textAlign,
    required this.rotationRadians,
    required this.baseStyle,
    required this.tokens,
    required this.index,
    this.background,
  });

  final double left;
  final double top;
  final double width;
  final TextAlign textAlign;
  final double rotationRadians;
  final TextStyle baseStyle;
  final OverlayTextBackgroundFrame? background;
  final List<OverlayTokenFrame> tokens;
  final int index;
}

@immutable
class OverlayTokenFrame {
  const OverlayTokenFrame({
    required this.raw,
    required this.isWord,
    required this.style,
    this.globalWordIndex,
  });

  final String raw;
  final bool isWord;
  final TextStyle style;
  final int? globalWordIndex;
}

@immutable
class OverlayTextBackgroundFrame {
  const OverlayTextBackgroundFrame({
    required this.color,
    required this.padding,
    required this.borderRadius,
  });

  final Color color;
  final double padding;
  final double borderRadius;
}
