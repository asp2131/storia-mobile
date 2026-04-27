import 'package:cue/cue.dart';
import 'package:flutter/material.dart';

import 'overlay_frame.dart';

/// Per-element word-stagger entrance (Feature 4).
///
/// When a page becomes active and this element mounts (virtualization window
/// brings it into the tree), each word rises + fades in with a short stagger
/// derived from its token index within the element. The stagger is
/// entrance-only: once played, TTS word-highlight styling drives appearance.
class OverlayTextElement extends StatelessWidget {
  final OverlayElementFrame element;
  final bool isActive;
  final void Function(String word, int globalIndex)? onWordTap;
  final void Function(String word, int globalIndex)? onWordLongPress;

  const OverlayTextElement({
    super.key,
    required this.element,
    required this.isActive,
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

    // Stagger: element index drives base delay. Cue.onToggle plays forward
    // when this page becomes active and reverses when it leaves. Adjacent
    // pages in the virtualization window stay hidden at progress 0 until they
    // become active, matching the old flutter_animate behavior.
    final delayMs = 180 + element.index * 40;

    return Positioned(
      left: element.left,
      top: element.top,
      width: element.width,
      child: Cue.onToggle(
        toggled: isActive,
        motion: .smooth(),
        child: Actor(
          delay: Duration(milliseconds: delayMs),
          acts: const [OpacityAct.fadeIn(), SlideAct.y(from: 0.12)],
          child: rotated,
        ),
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
        Widget wordWidget = token.pronunciationHighlightParts.isNotEmpty
            ? _PronunciationWordText(token: token)
            : Text(token.raw, style: token.style);
        if (token.isTapped) {
          wordWidget = AnimatedScale(
            scale: 1.15,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: wordWidget,
          );
        }
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
