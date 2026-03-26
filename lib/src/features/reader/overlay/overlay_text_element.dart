import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'overlay_frame.dart';

class OverlayTextElement extends StatelessWidget {
  final OverlayElementFrame element;
  final bool isActive;
  final void Function(String word, int globalIndex)? onWordTap;

  const OverlayTextElement({
    super.key,
    required this.element,
    required this.isActive,
    this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = RichText(
      textAlign: element.textAlign,
      text: TextSpan(
        style: element.baseStyle,
        children: _buildSpans(element.tokens),
      ),
    );

    final background = element.background;
    if (background != null) {
      content = Container(
        padding: EdgeInsets.all(background.padding),
        decoration: BoxDecoration(
          color: background.color,
          borderRadius: BorderRadius.circular(background.borderRadius),
        ),
        child: content,
      );
    }

    final rotated = element.rotationRadians != 0
        ? Transform.rotate(angle: element.rotationRadians, child: content)
        : content;

    return Positioned(
      left: element.left,
      top: element.top,
      width: element.width,
      child: rotated
          .animate(target: isActive ? 1 : 0)
          .fadeIn(
            duration: 350.ms,
            delay: Duration(milliseconds: 180 + element.index * 40),
          )
          .slideY(
            begin: 0.12,
            end: 0,
            duration: 350.ms,
            delay: Duration(milliseconds: 180 + element.index * 40),
          ),
    );
  }

  List<InlineSpan> _buildSpans(List<OverlayTokenFrame> tokens) {
    final spans = <InlineSpan>[];

    for (final token in tokens) {
      if (!token.isWord) {
        spans.add(TextSpan(text: token.raw, style: token.style));
        continue;
      }

      final index = token.globalWordIndex;
      if (onWordTap != null && index != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onWordTap?.call(token.raw, index),
              child: Text(token.raw, style: token.style),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: token.raw, style: token.style));
      }
    }

    return spans;
  }
}
