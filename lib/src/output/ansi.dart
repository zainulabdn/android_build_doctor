import 'dart:io';

/// How many colours the output may use.
enum ColorDepth {
  /// Plain text: no escape codes at all.
  none,

  /// The 16 theme colours. Terminal themes redefine them, so they always
  /// suit the user's background.
  ansi16,

  /// The xterm 256-colour palette.
  ansi256,

  /// 24-bit colour.
  trueColor,
}

/// A colour: a 24-bit value for capable terminals and the matching
/// 16-colour code for the rest.
class Tone {
  /// Creates a tone from `0xRRGGBB` and a 16-colour foreground SGR code
  /// (30-37 or 90-97). The background code is derived from it.
  const Tone(this.rgb, this.ansi16);

  /// The 24-bit value, `0xRRGGBB`.
  final int rgb;

  /// The 16-colour foreground SGR code used when 24-bit colour is off.
  final int ansi16;

  /// Red channel, 0-255.
  int get red => (rgb >> 16) & 0xff;

  /// Green channel, 0-255.
  int get green => (rgb >> 8) & 0xff;

  /// Blue channel, 0-255.
  int get blue => rgb & 0xff;

  /// `#rrggbb`.
  String get hex => '#${rgb.toRadixString(16).padLeft(6, '0')}';

  /// The nearest entry of the xterm 256-colour cube or grey ramp. The 16
  /// system colours are skipped on purpose: themes redefine them.
  int get xterm256 {
    const levels = [0, 95, 135, 175, 215, 255];
    int nearest(int v) {
      var best = 0;
      for (var i = 1; i < levels.length; i++) {
        if ((levels[i] - v).abs() < (levels[best] - v).abs()) best = i;
      }
      return best;
    }

    int distance(int r, int g, int b) =>
        (red - r) * (red - r) +
        (green - g) * (green - g) +
        (blue - b) * (blue - b);

    final r = nearest(red), g = nearest(green), b = nearest(blue);
    final step = (((red + green + blue) ~/ 3 - 8) / 10).round().clamp(0, 23);
    final grey = 8 + 10 * step;
    return distance(levels[r], levels[g], levels[b]) <=
            distance(grey, grey, grey)
        ? 16 + 36 * r + 6 * g + b
        : 232 + step;
  }
}

/// The colour tokens every view uses.
///
/// The terminal background is unknown (light and dark themes are both
/// common), so each *mark* colour was checked with the WCAG contrast formula
/// against white, Solarized Light and four dark backgrounds (`#1a1a19`,
/// `#1e1e1e`, `#282c34`, `#002b36`). Each keeps at least 3:1 on all six.
///
/// Text is never painted in these colours. It stays in the terminal's own
/// foreground (or its dim variant), which the theme keeps readable. Colour
/// goes on symbols, badges, borders and meters only, and always next to a
/// symbol or a word, so it never carries meaning on its own.
abstract final class Tones {
  /// Errors: the ✗ symbol, borders and meters. 4.30:1 on white, 3.26:1 on
  /// `#282c34`.
  static const Tone error = Tone(0xD94545, 31);

  /// Warnings: the ▲ symbol, borders and meters. 3.29:1 on white, 4.26:1 on
  /// `#282c34`.
  static const Tone warning = Tone(0xC47F00, 33);

  /// Success: the ✓ symbol, borders and meters. 3.35:1 on white, 4.17:1 on
  /// `#282c34`.
  static const Tone good = Tone(0x0CA30C, 32);

  /// The brand accent, also used for informational findings. 4.42:1 on
  /// white, 3.17:1 on `#282c34`.
  static const Tone accent = Tone(0x2A78D6, 34);

  /// Fill of the ERROR badge. White text on it measures 4.80:1.
  static const Tone errorFill = Tone(0xD03B3B, 31);

  /// Fill of the WARN badge. Ink text on it measures 10.73:1.
  static const Tone warningFill = Tone(0xFAB219, 33);

  /// Fill of the INFO badge. White text on it measures 5.39:1.
  static const Tone infoFill = Tone(0x256ABF, 34);

  /// Fill of the OK badge. Ink text on it measures 5.87:1.
  static const Tone goodFill = Tone(0x0CA30C, 32);

  /// Text on dark fills.
  static const Tone white = Tone(0xFFFFFF, 97);

  /// Text on light fills.
  static const Tone ink = Tone(0x0B0B0B, 30);
}

/// ANSI styling. Everything degrades to plain text when colour is off
/// (`--no-color`, `--ci`, `NO_COLOR`, output piped to a file).
class Ansi {
  /// Creates a helper.
  ///
  /// `enabled: false` turns every escape code off; `enabled: true` forces
  /// colour even when stdout is not a terminal. `depth` pins the colour
  /// depth (tests and screenshots). Otherwise the depth is detected from
  /// the environment and from whether stdout is a terminal.
  Ansi({bool? enabled, ColorDepth? depth})
    : depth = enabled == false
          ? ColorDepth.none
          : depth ??
                (enabled == true
                    ? _hinted(Platform.environment) ?? ColorDepth.ansi16
                    : detectDepth(
                        Platform.environment,
                        isTerminal:
                            stdout.hasTerminal && stdout.supportsAnsiEscapes,
                      ));

  /// The colour depth in use.
  final ColorDepth depth;

  /// Whether escape codes are emitted.
  bool get enabled => depth != ColorDepth.none;

  /// Detects the colour depth from `environment`.
  ///
  /// `FORCE_COLOR` wins (`0`/`false` off, `2` 256 colours, `3` 24-bit, any
  /// other value on). Then a non-empty `NO_COLOR`, `TERM=dumb` or a
  /// non-terminal turn colour off. Otherwise `COLORTERM`, `TERM_PROGRAM`,
  /// `WT_SESSION` and `TERM` decide between 24-bit, 256 and 16 colours.
  static ColorDepth detectDepth(
    Map<String, String> environment, {
    required bool isTerminal,
  }) {
    final force = environment['FORCE_COLOR'];
    if (force != null) {
      return switch (force.trim().toLowerCase()) {
        '0' || 'false' => ColorDepth.none,
        '2' => ColorDepth.ansi256,
        '3' => ColorDepth.trueColor,
        _ => _hinted(environment) ?? ColorDepth.ansi16,
      };
    }
    final noColor = environment['NO_COLOR'];
    if (noColor != null && noColor.isNotEmpty) return ColorDepth.none;
    if (environment['TERM'] == 'dumb' || !isTerminal) return ColorDepth.none;
    return _hinted(environment) ?? ColorDepth.ansi16;
  }

  static const Set<String> _trueColorApps = {
    'iTerm.app',
    'vscode',
    'WezTerm',
    'ghostty',
    'Hyper',
    'Tabby',
    'rio',
    'WarpTerminal',
  };

  static ColorDepth? _hinted(Map<String, String> env) {
    final colorTerm = (env['COLORTERM'] ?? '').toLowerCase();
    if (colorTerm == 'truecolor' || colorTerm == '24bit') {
      return ColorDepth.trueColor;
    }
    if (env.containsKey('WT_SESSION') ||
        _trueColorApps.contains(env['TERM_PROGRAM'])) {
      return ColorDepth.trueColor;
    }
    final term = (env['TERM'] ?? '').toLowerCase();
    if (term.contains('truecolor') ||
        term.contains('24bit') ||
        term.endsWith('-direct')) {
      return ColorDepth.trueColor;
    }
    if (term.contains('256') || env['TERM_PROGRAM'] == 'Apple_Terminal') {
      return ColorDepth.ansi256;
    }
    return null;
  }

  String _code(Tone tone, {required bool background}) => switch (depth) {
    ColorDepth.trueColor =>
      '${background ? 48 : 38};2;${tone.red};${tone.green};${tone.blue}',
    ColorDepth.ansi256 => '${background ? 48 : 38};5;${tone.xterm256}',
    _ => '${tone.ansi16 + (background ? 10 : 0)}',
  };

  String _wrap(String on, String off, String text) =>
      enabled && text.isNotEmpty ? '\x1B[${on}m$text\x1B[${off}m' : text;

  /// `text` in `tone`.
  String fg(Tone tone, String text) =>
      _wrap(_code(tone, background: false), '39', text);

  /// `text` on a `tone` background.
  String bg(Tone tone, String text) =>
      _wrap(_code(tone, background: true), '49', text);

  /// `text` in one of the 16 theme colours (`code` 30-37 or 90-97), at
  /// every colour depth. Used for long runs of coloured text such as diff
  /// lines, where the user's theme knows best what stays readable.
  String theme(int code, String text) => _wrap('$code', '39', text);

  /// A solid label: bold `ink` text on a `fill` block.
  String badge(String label, Tone fill, Tone ink) => _wrap(
    '1;${_code(ink, background: false)};${_code(fill, background: true)}',
    '22;39;49',
    label,
  );

  /// Bold.
  String bold(String text) => _wrap('1', '22', text);

  /// Dim: the terminal's foreground, faded. Used for secondary text.
  String dim(String text) => _wrap('2', '22', text);

  /// Error tone.
  String red(String text) => fg(Tones.error, text);

  /// Success tone.
  String green(String text) => fg(Tones.good, text);

  /// Warning tone.
  String yellow(String text) => fg(Tones.warning, text);

  /// Accent tone.
  String blue(String text) => fg(Tones.accent, text);

  /// Accent tone (kept for callers of the 0.1 API).
  String cyan(String text) => fg(Tones.accent, text);
}
