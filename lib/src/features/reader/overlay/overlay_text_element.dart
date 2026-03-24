import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../data/models.dart';
import 'text_overlay_utils.dart';

class OverlayTextElement extends StatelessWidget {
  final TextElement element;
  final int elementIndex;
  final Size imageSize;
  final int wordStartIndex;
  final int activeWordIndex;
  final Set<int> spokenWordIndices;
  final bool isActive;
  final void Function(String word, int globalIndex)? onWordTap;

  const OverlayTextElement({
    super.key,
    required this.element,
    required this.elementIndex,
    required this.imageSize,
    required this.wordStartIndex,
    required this.activeWordIndex,
    required this.isActive,
    this.spokenWordIndices = const {},
    this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final left = (element.x / 100) * imageSize.width;
    final top = (element.y / 100) * imageSize.height;
    final width = (element.width / 100) * imageSize.width;
    final fontSize = (element.fontSize / 100) * imageSize.height;

    final baseStyle =
        resolveFontStyle(
          element.fontFamily,
          element.fontWeight,
          fontSize,
          parseHexColor(element.color),
        ).copyWith(
          height: 1.3,
          shadows: element.shadow == null
              ? null
              : [
                  Shadow(
                    color: parseHexColor(
                      element.shadow!.color,
                      fallback: Colors.black,
                    ),
                    offset: Offset(element.shadow!.x, element.shadow!.y),
                    blurRadius: element.shadow!.blur,
                  ),
                ],
        );

    final background = element.background;

    Widget content = RichText(
      textAlign: resolveTextAlign(element.textAlign),
      text: TextSpan(style: baseStyle, children: _buildSpans(baseStyle, spokenWordIndices)),
    );

    if (background != null) {
      content = Container(
        padding: EdgeInsets.all(background.padding ?? 0),
        decoration: BoxDecoration(
          color: parseHexColor(background.color, fallback: Colors.transparent),
          borderRadius: BorderRadius.circular(background.borderRadius ?? 0),
        ),
        child: content,
      );
    }

    final rotated = element.rotation != 0
        ? Transform.rotate(
            angle: (element.rotation * 3.141592653589793) / 180,
            child: content,
          )
        : content;

    return Positioned(
      left: left,
      top: top,
      width: width,
      child: rotated
          .animate(target: isActive ? 1 : 0)
          .fadeIn(
            duration: 350.ms,
            delay: Duration(milliseconds: 180 + elementIndex * 40),
          )
          .slideY(
            begin: 0.12,
            end: 0,
            duration: 350.ms,
            delay: Duration(milliseconds: 180 + elementIndex * 40),
          ),
    );
  }

  List<InlineSpan> _buildSpans(TextStyle baseStyle, Set<int> spokenWordIndices) {
    final tokens = RegExp(
      r'\s+|\S+',
    ).allMatches(element.text).map((m) => m.group(0) ?? '').toList();
    final spans = <InlineSpan>[];
    var currentWordIndex = wordStartIndex;

    for (final token in tokens) {
      if (token.trim().isEmpty) {
        spans.add(TextSpan(text: token, style: baseStyle));
        continue;
      }

      final globalIndex = currentWordIndex;
      currentWordIndex += 1;
      final isNarrationHighlighted = globalIndex == activeWordIndex;
      final isSpoken = spokenWordIndices.contains(globalIndex);

      final wordStyle = isSpoken
          ? baseStyle.copyWith(
              backgroundColor: const Color.fromRGBO(255, 213, 79, 0.85),
              fontWeight: FontWeight.w800,
            )
          : isNarrationHighlighted
              ? baseStyle.copyWith(
                  backgroundColor: const Color.fromRGBO(212, 237, 188, 0.8),
                  fontWeight: FontWeight.w700,
                )
              : baseStyle;

      if (onWordTap != null) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onWordTap?.call(token, globalIndex),
              child: Text(token, style: wordStyle),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: token, style: wordStyle));
      }
    }

    return spans;
  }
}
