import 'dart:io';

/// Tiny ANSI colour helper. Colours are off when `--ci`/`--no-color` is
/// given, when `NO_COLOR` is set, or when stdout is not a terminal.
class Ansi {
  /// Creates a helper; `enabled` forces colours on or off.
  Ansi({bool? enabled}) : enabled = enabled ?? _detect();

  /// Whether escape codes are emitted.
  final bool enabled;

  static bool _detect() {
    if (Platform.environment.containsKey('NO_COLOR')) return false;
    if (Platform.environment['TERM'] == 'dumb') return false;
    return stdout.hasTerminal && stdout.supportsAnsiEscapes;
  }

  String _wrap(String code, String text) =>
      enabled ? '\x1B[${code}m$text\x1B[0m' : text;

  /// Red.
  String red(String t) => _wrap('31', t);

  /// Green.
  String green(String t) => _wrap('32', t);

  /// Yellow.
  String yellow(String t) => _wrap('33', t);

  /// Blue.
  String blue(String t) => _wrap('34', t);

  /// Cyan.
  String cyan(String t) => _wrap('36', t);

  /// Dim / grey.
  String dim(String t) => _wrap('2', t);

  /// Bold.
  String bold(String t) => _wrap('1', t);
}
