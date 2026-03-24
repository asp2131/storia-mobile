import 'package:flutter/material.dart';

import '../../../data/models.dart';
import 'overlay_text_element.dart';
import 'text_overlay_utils.dart';

class OverlayTextLayer extends StatelessWidget {
  final TextOverlayConfig overlay;
  final Size imageSize;
  final int activeWordIndex;
  final Set<int> spokenWordIndices;
  final bool isActive;
  final void Function(String word, int globalIndex)? onWordTap;

  const OverlayTextLayer({
    super.key,
    required this.overlay,
    required this.imageSize,
    required this.activeWordIndex,
    required this.isActive,
    this.spokenWordIndices = const {},
    this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    if (imageSize.width <= 0 || imageSize.height <= 0) {
      return const SizedBox.shrink();
    }

    final wordStarts = calculateWordStartsByElementId(overlay);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < overlay.elements.length; i++)
          OverlayTextElement(
            element: overlay.elements[i],
            elementIndex: i,
            imageSize: imageSize,
            wordStartIndex: wordStarts[overlay.elements[i].id] ?? 0,
            activeWordIndex: activeWordIndex,
            spokenWordIndices: spokenWordIndices,
            isActive: isActive,
            onWordTap: onWordTap,
          ),
      ],
    );
  }
}
