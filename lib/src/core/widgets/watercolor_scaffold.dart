import 'package:flutter/material.dart';

import '../theme/storia_colors.dart';
import 'paper_texture_overlay.dart';
import 'watercolor_blobs.dart';

class WatercolorScaffold extends StatelessWidget {
  const WatercolorScaffold({
    super.key,
    required this.child,
    this.backgroundColor = StoriaColors.paper,
    this.dark = false,
  });

  final Widget child;
  final Color backgroundColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WatercolorBlobs(dark: dark),
          PaperTextureOverlay(opacity: dark ? 0.1 : 0.2),
          child,
        ],
      ),
    );
  }
}
