import 'package:flutter/material.dart';

import 'overlay_frame.dart';
import 'overlay_text_element.dart';

class OverlayTextLayer extends StatelessWidget {
  final OverlayFrame frame;
  final void Function(String word, int globalIndex)? onWordTap;

  const OverlayTextLayer({
    super.key,
    required this.frame,
    this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    if (frame.elements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final element in frame.elements)
          OverlayTextElement(
            element: element,
            isActive: frame.isActive,
            onWordTap: onWordTap,
          ),
      ],
    );
  }
}
