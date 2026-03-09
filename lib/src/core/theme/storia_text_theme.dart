import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'storia_colors.dart';

TextTheme buildStoriaTextTheme(TextTheme base) {
  final body = GoogleFonts.nunitoTextTheme(
    base,
  ).apply(bodyColor: StoriaColors.ink, displayColor: StoriaColors.ink);

  return body.copyWith(
    displayLarge: GoogleFonts.lora(
      fontSize: 40,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      color: StoriaColors.ink,
      height: 1.05,
    ),
    displayMedium: GoogleFonts.lora(
      fontSize: 34,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      color: StoriaColors.ink,
      height: 1.08,
    ),
    headlineLarge: GoogleFonts.lora(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      color: StoriaColors.ink,
      height: 1.1,
    ),
    headlineMedium: GoogleFonts.lora(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
      color: StoriaColors.ink,
      height: 1.15,
    ),
    titleLarge: GoogleFonts.lora(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: StoriaColors.ink,
      height: 1.15,
    ),
    titleMedium: GoogleFonts.nunito(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: StoriaColors.ink,
      height: 1.2,
    ),
    bodyLarge: GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: StoriaColors.ink,
      height: 1.45,
    ),
    bodyMedium: GoogleFonts.nunito(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: StoriaColors.ink,
      height: 1.45,
    ),
    bodySmall: GoogleFonts.nunito(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: StoriaColors.inkMuted,
      height: 1.35,
    ),
    labelLarge: GoogleFonts.nunito(
      fontSize: 15,
      fontWeight: FontWeight.w900,
      color: StoriaColors.ink,
      letterSpacing: 0.2,
    ),
  );
}
