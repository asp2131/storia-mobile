import 'package:flutter/material.dart';

import '../../../data/models.dart';
import '../pronunciation_highlight.dart';
import 'overlay_frame.dart';
import 'text_overlay_utils.dart';

abstract interface class OverlayLayoutEngine {
  OverlayFrame build({
    required TextOverlayConfig overlay,
    required Size imageSize,
    required int activeWordIndex,
    required Set<int> spokenWordIndices,
    required bool isActive,
    int? tappedWordIndex,
    List<PronunciationHighlightPart> tappedWordHighlightParts = const [],
    int? activeTappedWordHighlightPartIndex,
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
    int? tappedWordIndex,
    List<PronunciationHighlightPart> tappedWordHighlightParts = const [],
    int? activeTappedWordHighlightPartIndex,
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
                      offset: Offset(
                        (element.shadow!.x / 100) * imageSize.width,
                        (element.shadow!.y / 100) * imageSize.height,
                      ),
                      blurRadius: (element.shadow!.blur / 100) * imageSize.width,
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

        final isTapped = globalIndex == tappedWordIndex;
        final hasSegmentHighlight =
            isTapped && tappedWordHighlightParts.isNotEmpty;
        final isNarrationHighlighted = globalIndex == activeWordIndex;
        final isSpoken = spokenWordIndices.contains(globalIndex);

        final style = isTapped
            ? baseStyle.copyWith(
                backgroundColor: hasSegmentHighlight
                    ? null
                    : const Color.fromRGBO(139, 92, 246, 0.85),
                fontWeight: hasSegmentHighlight
                    ? baseStyle.fontWeight
                    : FontWeight.w900,
                color: hasSegmentHighlight
                    ? baseStyle.color
                    : Colors.white,
              )
            : isSpoken
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
            isTapped: isTapped,
            pronunciationHighlightParts: hasSegmentHighlight
                ? tappedWordHighlightParts
                : const [],
            activePronunciationHighlightPartIndex: hasSegmentHighlight
                ? activeTappedWordHighlightPartIndex
                : null,
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
              padding: ((element.background!.padding ?? 0) / 100) * imageSize.width,
              borderRadius: ((element.background!.borderRadius ?? 0) / 100) * imageSize.width,
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

    return OverlayFrame(
      elements: elements,
      isActive: isActive,
      tappedWordIndex: tappedWordIndex,
    );
  }
}
