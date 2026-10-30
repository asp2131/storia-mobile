import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warm "Library v2" palette from the Claude Design mockup; the entry flow
/// keeps [LoratoneEntryColors].
abstract final class LoratoneLibraryColors {
  static const paper = Color(0xFFFFF8EC);
  static const surface = Colors.white;
  static const ink = Color(0xFF1A1A1A);
  static const inkMuted = Color(0xFF5A4A3A);
  static const orange = Color(0xFFFF8549);
  static const yellow = Color(0xFFFFC53D);
  static const blue = Color(0xFF389CEE);
  static const navy = Color(0xFF1E2A55);
  static const track = Color(0xFFF1E6D4);
  static const line = Color(0xFFEFE3D0);
  static const shadow = Color.fromRGBO(80, 50, 20, 0.14);

  /// Cover backdrops, cycled by book so untitled art still looks intentional.
  static const coverTints = [
    yellow,
    Color(0xFFFFC4C8),
    blue,
    Color(0xFF7FB59A),
    Color(0xFF9AAEF5),
    orange,
  ];

  static const cardShadow = [
    BoxShadow(color: shadow, blurRadius: 18, offset: Offset(0, 6)),
  ];
}

/// Headings: Grandstander, the mockup's hand-lettered display face.
TextStyle libraryDisplay({
  double size = 22,
  FontWeight weight = FontWeight.w900,
  Color color = LoratoneLibraryColors.ink,
  double height = 1.1,
}) => GoogleFonts.grandstander(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

/// Body: Atkinson Hyperlegible, chosen for early readers.
TextStyle libraryBody({
  double size = 14,
  FontWeight weight = FontWeight.w400,
  Color color = LoratoneLibraryColors.ink,
  double height = 1.35,
}) => GoogleFonts.atkinsonHyperlegible(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);
