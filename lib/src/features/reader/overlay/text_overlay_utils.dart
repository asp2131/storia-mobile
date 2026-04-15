import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/models.dart';

Rect computeContainedImageRect({
  required Size container,
  required Size sourceImage,
}) {
  if (container.width <= 0 ||
      container.height <= 0 ||
      sourceImage.width <= 0 ||
      sourceImage.height <= 0) {
    return .zero;
  }

  final containerAspect = container.width / container.height;
  final imageAspect = sourceImage.width / sourceImage.height;

  if (imageAspect > containerAspect) {
    final width = container.width;
    final height = width / imageAspect;
    final y = (container.height - height) / 2;
    return Rect.fromLTWH(0, y, width, height);
  }

  final height = container.height;
  final width = height * imageAspect;
  final x = (container.width - width) / 2;
  return Rect.fromLTWH(x, 0, width, height);
}

int computeActiveWordIndex(
  List<WordTimestamp>? timestamps,
  Duration currentPosition,
) {
  if (timestamps == null || timestamps.isEmpty) {
    return -1;
  }

  final currentTime = currentPosition.inMilliseconds / 1000;
  var foundIndex = -1;

  for (var i = 0; i < timestamps.length; i++) {
    final word = timestamps[i];
    final nextWord = i + 1 < timestamps.length ? timestamps[i + 1] : null;

    if (currentTime >= word.start && currentTime <= word.end) {
      foundIndex = i;
      break;
    }
    if (nextWord != null &&
        currentTime > word.end &&
        currentTime < nextWord.start) {
      foundIndex = i;
      break;
    }
    if (nextWord == null && currentTime >= word.start) {
      foundIndex = i;
      break;
    }
    if (currentTime > word.end) {
      foundIndex = i;
    }
  }

  return foundIndex;
}

Color parseHexColor(String value, {Color fallback = Colors.white}) {
  var hex = value.trim();
  if (hex.isEmpty) {
    return fallback;
  }
  if (hex.startsWith('#')) {
    hex = hex.substring(1);
  }
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  if (hex.length != 8) {
    return fallback;
  }
  final intValue = int.tryParse(hex, radix: 16);
  if (intValue == null) {
    return fallback;
  }
  return Color(intValue);
}

TextAlign resolveTextAlign(String value) {
  switch (value) {
    case 'center':
      return .center;
    case 'right':
      return .right;
    default:
      return .left;
  }
}

TextStyle resolveFontStyle(
  String family,
  int weight,
  double size,
  Color color,
) {
  final fw = FontWeight.values.firstWhere(
    (w) => w.value == weight,
    orElse: () => .w400,
  );

  final fallbackStyle = TextStyle(
    fontFamily: family.isEmpty ? 'Inter' : family,
    fontSize: size,
    color: color,
    fontWeight: fw,
  );
  final isTestBinding = WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  if (!GoogleFonts.config.allowRuntimeFetching || isTestBinding) {
    return fallbackStyle;
  }

  try {
    switch (family) {
      case 'Lora':
        return GoogleFonts.lora(fontSize: size, color: color, fontWeight: fw);
      case 'Playfair Display':
        return GoogleFonts.playfairDisplay(
          fontSize: size,
          color: color,
          fontWeight: fw,
        );
      case 'JetBrains Mono':
        return GoogleFonts.jetBrainsMono(
          fontSize: size,
          color: color,
          fontWeight: fw,
        );
      case 'Gaegu':
        return GoogleFonts.gaegu(fontSize: size, color: color, fontWeight: fw);
      default:
        return GoogleFonts.inter(fontSize: size, color: color, fontWeight: fw);
    }
  } catch (_) {
    return fallbackStyle;
  }
}
