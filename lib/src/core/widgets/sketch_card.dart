import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';
import 'sketch_border.dart';

class SketchCard extends StatelessWidget {
  const SketchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = StoriaColors.paperRaised,
    this.borderColor = StoriaColors.line,
    this.elevation = 0.08,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color,
        shape: SketchBorderShape(
          side: BorderSide(color: borderColor, width: 1.2),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: elevation),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
