import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/data/models.dart';
import 'package:loratone/src/features/reader/overlay/overlay_layout_engine.dart';
import 'package:loratone/src/features/reader/overlay/text_overlay_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  debugUseSystemFontsForOverlay = true;
  const engine = OverlayLayoutEngineImpl();

  test(
    'builds deterministic element geometry and highlighted tokens',
    () async {
      const overlay = TextOverlayConfig(
        version: 1,
        elements: [
          TextElement(
            id: 'line-1',
            text: 'Hello world',
            x: 10,
            y: 20,
            width: 80,
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: 400,
            color: '#FFFFFF',
            textAlign: 'left',
            rotation: 0,
          ),
        ],
      );

      final frame = engine.build(
        overlay: overlay,
        imageSize: const Size(200, 400),
        activeWordIndex: 1,
        spokenWordIndices: const {0},
        isActive: true,
      );
      expect(frame.elements.length, 1);
      final element = frame.elements.first;
      expect(element.left, 20);
      expect(element.top, 80);
      expect(element.width, 160);

      final tokens = element.tokens.where((t) => t.isWord).toList();
      expect(tokens.length, 2);
      expect(tokens[0].raw, 'Hello');
      expect(tokens[0].globalWordIndex, 0);
      expect(
        tokens[0].style.backgroundColor,
        const Color.fromRGBO(255, 213, 79, 0.85),
      );

      expect(tokens[1].raw, 'world');
      expect(tokens[1].globalWordIndex, 1);
      expect(
        tokens[1].style.backgroundColor,
        const Color.fromRGBO(212, 237, 188, 0.8),
      );
    },
  );

  test('keeps whitespace tokens so rich text spacing remains stable', () async {
    const overlay = TextOverlayConfig(
      version: 1,
      elements: [
        TextElement(
          id: 'line-1',
          text: 'A   B',
          x: 0,
          y: 0,
          width: 100,
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: 400,
          color: '#FFFFFF',
          textAlign: 'left',
          rotation: 0,
        ),
      ],
    );

    final frame = engine.build(
      overlay: overlay,
      imageSize: const Size(100, 100),
      activeWordIndex: -1,
      spokenWordIndices: const {},
      isActive: false,
    );
    final tokens = frame.elements.first.tokens;
    expect(tokens.length, 3);
    expect(tokens[1].isWord, false);
    expect(tokens[1].raw, '   ');
  });
}
