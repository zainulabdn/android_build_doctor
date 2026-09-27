import 'dart:math' as math;

import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:test/test.dart';

/// WCAG 2 relative luminance of `0xRRGGBB`.
double luminance(int rgb) {
  double channel(int shift) {
    final c = ((rgb >> shift) & 0xff) / 255;
    return c <= 0.04045
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

/// WCAG 2 contrast ratio between two colours.
double contrast(int a, int b) {
  final la = luminance(a), lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  // The tool cannot know the user's terminal theme, so mark colours must
  // stay visible on light and dark backgrounds alike.
  const backgrounds = {
    'white': 0xFFFFFF,
    'Solarized Light': 0xFDF6E3,
    'near black': 0x1A1A19,
    'VS Code dark': 0x1E1E1E,
    'One Dark': 0x282C34,
    'Solarized Dark': 0x002B36,
  };
  const marks = {
    'error': Tones.error,
    'warning': Tones.warning,
    'good': Tones.good,
    'accent': Tones.accent,
  };

  for (final mark in marks.entries) {
    test('${mark.key} keeps 3:1 on every background', () {
      for (final bg in backgrounds.entries) {
        expect(
          contrast(mark.value.rgb, bg.value),
          greaterThanOrEqualTo(3.0),
          reason: '${mark.key} ${mark.value.hex} on ${bg.key}',
        );
      }
    });
  }

  test('badge text keeps 4.5:1 on its fill', () {
    for (final (fill, ink) in [
      (Tones.errorFill, Tones.white),
      (Tones.warningFill, Tones.ink),
      (Tones.infoFill, Tones.white),
      (Tones.goodFill, Tones.ink),
    ]) {
      expect(
        contrast(fill.rgb, ink.rgb),
        greaterThanOrEqualTo(4.5),
        reason: '${ink.hex} on ${fill.hex}',
      );
    }
  });
}
