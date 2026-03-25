import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'storia_colors.dart';

TextTheme buildStoriaTextTheme(TextTheme base) {
  final body = GoogleFonts.baloo2TextTheme(
    base,
  ).apply(bodyColor: StoriaColors.ink, displayColor: StoriaColors.ink);

  return body.copyWith(
    displayLarge: GoogleFonts.baloo2(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      color: StoriaColors.ink,
      height: 1.05,
    ),
    displayMedium: GoogleFonts.baloo2(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      color: StoriaColors.ink,
      height: 1.08,
    ),
    headlineLarge: GoogleFonts.baloo2(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      color: StoriaColors.ink,
      height: 1.1,
    ),
    headlineMedium: GoogleFonts.baloo2(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: StoriaColors.ink,
      height: 1.15,
    ),
    titleLarge: GoogleFonts.baloo2(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: StoriaColors.ink,
      height: 1.15,
    ),
    titleMedium: GoogleFonts.baloo2(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: StoriaColors.ink,
      height: 1.2,
    ),
    bodyLarge: GoogleFonts.baloo2(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: StoriaColors.ink,
      height: 1.45,
    ),
    bodyMedium: GoogleFonts.baloo2(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: StoriaColors.ink,
      height: 1.45,
    ),
    bodySmall: GoogleFonts.baloo2(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: StoriaColors.inkMuted,
      height: 1.35,
    ),
    labelLarge: GoogleFonts.baloo2(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      color: StoriaColors.ink,
      letterSpacing: 0.2,
    ),
  );
}
