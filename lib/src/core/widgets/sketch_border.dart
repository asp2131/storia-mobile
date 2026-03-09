import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';

BorderRadiusGeometry sketchBorderRadius([double scale = 1]) {
  return BorderRadius.only(
    topLeft: Radius.circular(28 * scale),
    topRight: Radius.circular(14 * scale),
    bottomLeft: Radius.circular(18 * scale),
    bottomRight: Radius.circular(30 * scale),
  );
}

class SketchBorderShape extends OutlinedBorder {
  final BorderSide _side;
  final double radiusScale;

  const SketchBorderShape({
    BorderSide side = const BorderSide(color: StoriaColors.lineStrong),
    this.radiusScale = 1,
  }) : _side = side;

  @override
  BorderSide get side => _side;

  @override
  ShapeBorder scale(double t) {
    return SketchBorderShape(
      side: _side.scale(t),
      radiusScale: radiusScale * t,
    );
  }

  @override
  SketchBorderShape copyWith({BorderSide? side}) {
    return SketchBorderShape(side: side ?? _side, radiusScale: radiusScale);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(
      sketchBorderRadius(
        radiusScale,
      ).resolve(textDirection).toRRect(rect).deflate(_side.width),
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(
      sketchBorderRadius(radiusScale).resolve(textDirection).toRRect(rect),
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (_side.style == BorderStyle.none) {
      return;
    }

    final paint = _side.toPaint();
    final rrect = sketchBorderRadius(
      radiusScale,
    ).resolve(textDirection).toRRect(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(_side.width);
}
