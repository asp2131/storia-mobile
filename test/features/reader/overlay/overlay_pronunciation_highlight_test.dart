import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:storia_kids/src/data/models.dart';
import 'package:storia_kids/src/features/reader/overlay/overlay_frame.dart';
import 'package:storia_kids/src/features/reader/overlay/overlay_layout_engine.dart';
import 'package:storia_kids/src/features/reader/overlay/overlay_text_element.dart';
import 'package:storia_kids/src/features/reader/overlay/text_overlay_utils.dart';
import 'package:storia_kids/src/features/reader/pronunciation_highlight.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugUseSystemFontsForOverlay = true;
  group('Overlay syllable pronunciation highlighting', () {
    test('layout attaches pronunciation parts only to the tapped word', () {
      const parts = [
        PronunciationHighlightPart(text: 'ba', startMs: 0, endMs: 650),
        PronunciationHighlightPart(text: 'na', startMs: 650, endMs: 1300),
        PronunciationHighlightPart(text: 'na', startMs: 1300, endMs: 1950),
      ];

      final frame = const OverlayLayoutEngineImpl().build(
        overlay: const TextOverlayConfig(
          version: 1,
          elements: [
            TextElement(
              id: 'line-1',
              text: 'Tap banana now',
              x: 0,
              y: 0,
              width: 100,
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: 400,
              color: '#111111',
              textAlign: 'left',
              rotation: 0,
            ),
          ],
        ),
        imageSize: const Size(300, 200),
        activeWordIndex: -1,
        spokenWordIndices: const {},
        isActive: true,
        tappedWordIndex: 1,
        tappedWordHighlightParts: parts,
        activeTappedWordHighlightPartIndex: 2,
      );

      final wordTokens = frame.elements.single.tokens
          .where((token) => token.isWord)
          .toList(growable: false);

      expect(wordTokens.map((token) => token.raw), ['Tap', 'banana', 'now']);
      expect(wordTokens[0].pronunciationHighlightParts, isEmpty);
      expect(wordTokens[1].pronunciationHighlightParts, same(parts));
      expect(wordTokens[1].activePronunciationHighlightPartIndex, 2);
      expect(wordTokens[1].style.backgroundColor, isNull);
      expect(wordTokens[2].pronunciationHighlightParts, isEmpty);
    });

    testWidgets('widget renders only active syllable with highlight', (
      tester,
    ) async {
      final taps = <({String word, int index})>[];
      final element = _elementFrame(
        raw: 'banana',
        parts: const [
          PronunciationHighlightPart(text: 'ba'),
          PronunciationHighlightPart(text: 'na'),
          PronunciationHighlightPart(text: 'na'),
        ],
        activeIndex: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                OverlayTextElement(
                  element: element,
                  onWordTap: (word, index) =>
                      taps.add((word: word, index: index)),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Active syllable 'na' should have the full highlight treatment.
      final activeNaSpans = _textSpansWithText('na')
          .where((span) {
            return span.style?.backgroundColor ==
                    const Color.fromRGBO(139, 92, 246, 0.9) &&
                span.style?.color == Colors.white &&
                span.style?.fontWeight == FontWeight.w900;
          })
          .toList(growable: false);

      // Inactive syllable 'ba' should have NO background.
      final inactiveSpans = _textSpansWithText('ba')
          .where((span) {
            return span.style?.backgroundColor == null;
          })
          .toList(growable: false);

      expect(activeNaSpans, hasLength(1));
      expect(inactiveSpans, hasLength(1));

      await tester.tap(find.byType(GestureDetector));
      expect(taps, [(word: 'banana', index: 4)]);
    });

    testWidgets(
      'widget falls back to whole-word highlight when parts mismatch',
      (tester) async {
        final element = _elementFrame(
          raw: 'whale',
          parts: const [
            PronunciationHighlightPart(text: 'not'),
            PronunciationHighlightPart(text: 'matching'),
          ],
          activeIndex: 0,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  OverlayTextElement(element: element, onWordTap: (_, _) {}),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        final fallbackText = tester.widget<Text>(find.text('whale'));
        expect(
          fallbackText.style?.backgroundColor,
          const Color.fromRGBO(139, 92, 246, 0.85),
        );
      },
    );

    testWidgets('widget shows whole-word fallback when active index is null', (
      tester,
    ) async {
      final element = _elementFrame(
        raw: 'banana',
        parts: const [
          PronunciationHighlightPart(text: 'ba'),
          PronunciationHighlightPart(text: 'na'),
          PronunciationHighlightPart(text: 'na'),
        ],
        activeIndex: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                OverlayTextElement(element: element, onWordTap: (_, _) {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final completedText = tester.widget<Text>(find.text('banana'));
      expect(
        completedText.style?.backgroundColor,
        const Color.fromRGBO(139, 92, 246, 0.85),
      );
      expect(completedText.style?.color, Colors.white);
      expect(completedText.style?.fontWeight, FontWeight.w900);
    });
  });
}

OverlayElementFrame _elementFrame({
  required String raw,
  required List<PronunciationHighlightPart> parts,
  required int? activeIndex,
}) {
  const style = TextStyle(color: Colors.black, fontSize: 24);
  return OverlayElementFrame(
    left: 0,
    top: 0,
    width: 300,
    textAlign: TextAlign.left,
    rotationRadians: 0,
    baseStyle: style,
    tokens: [
      OverlayTokenFrame(
        raw: raw,
        isWord: true,
        style: style.copyWith(color: Colors.white),
        globalWordIndex: 4,
        isTapped: true,
        pronunciationHighlightParts: parts,
        activePronunciationHighlightPartIndex: activeIndex,
      ),
    ],
    index: 0,
  );
}

List<TextSpan> _textSpansWithText(String text) {
  final spans = <TextSpan>[];
  final binding = TestWidgetsFlutterBinding.instance;
  final elements = binding.rootElement == null
      ? const <Element>[]
      : collectAllElementsFrom(binding.rootElement!, skipOffstage: false);

  for (final element in elements) {
    final widget = element.widget;
    if (widget is RichText) {
      _visitTextSpans(widget.text, (span) {
        if (span.text == text) {
          spans.add(span);
        }
      });
    }
  }
  return spans;
}

void _visitTextSpans(InlineSpan span, void Function(TextSpan span) visitor) {
  if (span is! TextSpan) {
    return;
  }
  visitor(span);
  for (final child in span.children ?? const <InlineSpan>[]) {
    _visitTextSpans(child, visitor);
  }
}
