import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loratone/src/features/reader/overlay/text_overlay_utils.dart';

void main() {
  group('parseHexColor', () {
    test('reads the hex forms the editor saves', () {
      expect(parseHexColor('#2F4B7C'), const Color(0xFF2F4B7C));
      expect(parseHexColor('#abc'), const Color(0xFFAABBCC));
      expect(parseHexColor('80000000'), const Color(0x80000000));
    });

    test('reads rgb() and rgba() used for see-through shadows and backgrounds', () {
      expect(parseHexColor('rgb(255, 128, 0)'), const Color.fromRGBO(255, 128, 0, 1));
      expect(parseHexColor('rgba(0, 0, 0, 0.5)'), const Color.fromRGBO(0, 0, 0, 0.5));
      expect(parseHexColor('RGBA(10,20,30,2)'), const Color.fromRGBO(10, 20, 30, 1));
    });

    test('falls back on anything else', () {
      expect(parseHexColor('tomato', fallback: Colors.transparent), Colors.transparent);
      expect(parseHexColor('', fallback: Colors.black), Colors.black);
    });
  });
}
