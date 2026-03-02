import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildAppTheme() {
  final textTheme = GoogleFonts.interTextTheme();

  return ThemeData(
    useMaterial3: true,
    textTheme: textTheme,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F7A8C)),
    scaffoldBackgroundColor: const Color(0xFFF7F7F4),
  );
}
