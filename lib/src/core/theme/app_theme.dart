import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme({Brightness brightness = .light}) {
  final textTheme = GoogleFonts.interTextTheme();
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1F7A8C),
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    textTheme: textTheme,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: brightness == .light
        ? const Color(0xFFF7F7F4)
        : colorScheme.surface,
  );
}
