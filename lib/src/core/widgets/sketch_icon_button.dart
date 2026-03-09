import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';
import 'sketch_border.dart';

class SketchIconButton extends StatelessWidget {
  const SketchIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = 46,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: IconButton.filled(
        onPressed: onPressed,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: StoriaColors.paperRaised,
          foregroundColor: StoriaColors.ink,
          shape: const SketchBorderShape(
            side: BorderSide(color: StoriaColors.line, width: 1.2),
          ),
        ),
        icon: Icon(icon),
      ),
    );
  }
}
