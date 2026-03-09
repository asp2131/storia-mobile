import 'package:flutter/material.dart';

import 'storia_colors.dart';
import 'storia_text_theme.dart';

ThemeData buildAppTheme({Brightness brightness = .light}) {
  if (brightness == Brightness.dark) {
    final colorScheme = const ColorScheme.dark(
      primary: StoriaColors.mustard,
      secondary: StoriaColors.dustyPink,
      surface: StoriaColors.readerChrome,
      onSurface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: StoriaColors.readerBackground,
      textTheme: buildStoriaTextTheme(
        ThemeData.dark().textTheme,
      ).apply(bodyColor: Colors.white, displayColor: Colors.white),
    );
  }

  const colorScheme = ColorScheme.light(
    primary: StoriaColors.ink,
    secondary: StoriaColors.dustyPink,
    tertiary: StoriaColors.sage,
    surface: StoriaColors.paper,
    onSurface: StoriaColors.ink,
    error: StoriaColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: StoriaColors.paper,
  );

  return base.copyWith(
    textTheme: buildStoriaTextTheme(base.textTheme),
    inputDecorationTheme: const InputDecorationTheme(border: InputBorder.none),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: StoriaColors.ink,
      contentTextStyle: TextStyle(color: StoriaColors.paper),
    ),
  );
}
