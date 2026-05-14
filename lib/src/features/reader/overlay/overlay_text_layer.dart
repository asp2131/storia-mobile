import 'package:cue/cue.dart';
import 'package:flutter/material.dart';

import 'overlay_frame.dart';
import 'overlay_text_element.dart';

class OverlayTextLayer extends StatelessWidget {
  final OverlayFrame frame;
  final void Function(String word, int globalIndex)? onWordTap;
  final void Function(String word, int globalIndex)? onWordLongPress;

  const OverlayTextLayer({
    super.key,
    required this.frame,
    this.onWordTap,
    this.onWordLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (frame.elements.isEmpty) {
      return const SizedBox.shrink();
    }

    // One scene-level Cue drives every overlay element. Each element contributes
    // its own Actor delay so the page entrance remains staggered while sharing
    // a single active-page controller.
    return Cue.onToggle(
      debugLabel: 'reader-overlay-text',
      toggled: frame.isActive,
      motion: .smooth(),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final element in frame.elements)
            OverlayTextElement(
              element: element,
              onWordTap: onWordTap,
              onWordLongPress: onWordLongPress,
            ),
        ],
      ),
    );
  }
}
