import 'package:flutter/material.dart';

import '../../../data/models.dart';
import 'overlay_frame.dart';
import 'text_overlay_utils.dart';

abstract interface class OverlayLayoutEngine {
  OverlayFrame build({
    required TextOverlayConfig overlay,
    required Size imageSize,
    required int activeWordIndex,
    required Set<int> spokenWordIndices,
    required bool isActive,
  });
}

class OverlayLayoutEngineImpl implements OverlayLayoutEngine {
  const OverlayLayoutEngineImpl();

  @override
  OverlayFrame build({
    required TextOverlayConfig overlay,
    required Size imageSize,
    required int activeWordIndex,
    required Set<int> spokenWordIndices,
    required bool isActive,
  }) {
    final elements = <OverlayElementFrame>[];
    var wordCursor = 0;

    for (var i = 0; i < overlay.elements.length; i++) {
      final element = overlay.elements[i];
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

      final tokenStrings = RegExp(
        r'\s+|\S+',
      ).allMatches(element.text).map((m) => m.group(0) ?? '').toList();

      final tokenFrames = <OverlayTokenFrame>[];
      for (final token in tokenStrings) {
        final isWord = token.trim().isNotEmpty;
        if (!isWord) {
          tokenFrames.add(
            OverlayTokenFrame(raw: token, isWord: false, style: baseStyle),
          );
          continue;
        }

        final globalIndex = wordCursor;
        wordCursor += 1;

        final isNarrationHighlighted = globalIndex == activeWordIndex;
        final isSpoken = spokenWordIndices.contains(globalIndex);

        final style = isSpoken
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

        tokenFrames.add(
          OverlayTokenFrame(
            raw: token,
            isWord: true,
            style: style,
            globalWordIndex: globalIndex,
          ),
        );
      }

      final background = element.background == null
          ? null
          : OverlayTextBackgroundFrame(
              color: parseHexColor(
                element.background!.color,
                fallback: Colors.transparent,
              ),
              padding: element.background!.padding ?? 0,
              borderRadius: element.background!.borderRadius ?? 0,
            );

      elements.add(
        OverlayElementFrame(
          left: left,
          top: top,
          width: width,
          textAlign: resolveTextAlign(element.textAlign),
          rotationRadians: (element.rotation * 3.141592653589793) / 180,
          baseStyle: baseStyle,
          background: background,
          tokens: tokenFrames,
          index: i,
        ),
      );
    }

    return OverlayFrame(elements: elements, isActive: isActive);
  }
}
