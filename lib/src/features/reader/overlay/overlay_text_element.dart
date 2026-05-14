import 'package:cue/cue.dart';
import 'package:flutter/material.dart';

import 'overlay_frame.dart';

/// Single positioned text element in the reader overlay scene.
///
/// [OverlayTextLayer] owns the scene-level Cue. This widget adds an Actor with
/// an element-specific delay so page text can rise + fade in as a coordinated
/// stagger when the active page changes.
class OverlayTextElement extends StatelessWidget {
  final OverlayElementFrame element;
  final void Function(String word, int globalIndex)? onWordTap;
  final void Function(String word, int globalIndex)? onWordLongPress;

  const OverlayTextElement({
    super.key,
    required this.element,
    this.onWordTap,
    this.onWordLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final content = RichText(
      textAlign: element.textAlign,
      text: TextSpan(
        style: element.baseStyle,
        children: _buildSpans(element.tokens),
      ),
    );

    Widget decorated = content;
    final background = element.background;
    if (background != null) {
      decorated = Container(
        padding: EdgeInsets.all(background.padding),
        decoration: BoxDecoration(
          color: background.color,
          borderRadius: BorderRadius.circular(background.borderRadius),
        ),
        child: decorated,
      );
    }

    final rotated = element.rotationRadians != 0
        ? Transform.rotate(angle: element.rotationRadians, child: decorated)
        : decorated;

    // Stagger: element index drives base delay on the parent Cue's timeline.
    // If the element is rendered in isolation (tests/tools), skip the Actor so
    // the text remains usable without requiring a Cue ancestor.
    final delayMs = 180 + element.index * 40;
    final Widget sceneChild = CueScope.maybeOf(context) == null
        ? rotated
        : Actor(
            delay: Duration(milliseconds: delayMs),
            acts: const [.fadeIn(), .slideY(from: 0.12)],
            child: rotated,
          );

    return Positioned(
      left: element.left,
      top: element.top,
      width: element.width,
      child: sceneChild,
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
        Widget wordWidget = token.pronunciationHighlightParts.isNotEmpty
            ? _PronunciationWordText(token: token)
            : Text(token.raw, style: token.style);
        wordWidget = Cue.onToggle(
          key: ValueKey('reader-word-pop-$index'),
          toggled: token.isTapped,
          motion: .spring(
            duration: const Duration(milliseconds: 220),
            bounce: 0.35,
          ),
          reverseMotion: .snappy(),
          acts: const [.scale(to: 1.15)],
          child: wordWidget,
        );
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onWordTap?.call(token.raw, index),
              onLongPress: () => onWordLongPress?.call(token.raw, index),
              child: wordWidget,
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

class _PronunciationWordText extends StatelessWidget {
  const _PronunciationWordText({required this.token});

  final OverlayTokenFrame token;

  static const Color _activePartBackground = Color.fromRGBO(139, 92, 246, 0.9);
  static const Color _fallbackWordBackground = Color.fromRGBO(
    139,
    92,
    246,
    0.85,
  );

  @override
  Widget build(BuildContext context) {
    final spans = _buildSegmentSpans();
    if (spans == null) {
      return _fallbackText(token.raw);
    }

    // If parts exist but no active index (e.g. past grace period),
    // show the whole word as "completed".
    if (token.activePronunciationHighlightPartIndex == null) {
      return _fallbackText(token.raw);
    }

    return RichText(
      text: TextSpan(style: token.style, children: spans),
      textScaler: MediaQuery.textScalerOf(context),
    );
  }

  Widget _fallbackText(String text) {
    return Text(
      text,
      style: token.style.copyWith(
        backgroundColor: _fallbackWordBackground,
        color: Colors.white,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  List<InlineSpan>? _buildSegmentSpans() {
    final raw = token.raw;
    final lowerRaw = raw.toLowerCase();
    final parts = token.pronunciationHighlightParts;
    var cursor = 0;
    final spans = <InlineSpan>[];

    for (var i = 0; i < parts.length; i++) {
      final partText = parts[i].text.trim();
      if (partText.isEmpty) {
        continue;
      }
      final matchIndex = lowerRaw.indexOf(partText.toLowerCase(), cursor);
      if (matchIndex < 0) {
        return null;
      }
      if (matchIndex > cursor) {
        // Unmatched prefix text — no background.
        spans.add(TextSpan(text: raw.substring(cursor, matchIndex)));
      }
      final end = matchIndex + partText.length;
      final isActive = i == token.activePronunciationHighlightPartIndex;
      spans.add(
        TextSpan(
          text: raw.substring(matchIndex, end),
          style: isActive
              ? token.style.copyWith(
                  backgroundColor: _activePartBackground,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                )
              : token.style, // No modifications for inactive syllables.
        ),
      );
      cursor = end;
    }

    if (cursor < raw.length) {
      // Unmatched suffix text — no background.
      spans.add(TextSpan(text: raw.substring(cursor)));
    }
    return spans.isEmpty ? null : spans;
  }
}
