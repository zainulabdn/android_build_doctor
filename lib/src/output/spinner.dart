import 'dart:async';
import 'dart:io';

import 'ansi.dart';
import 'glyphs.dart';

/// A one-line progress spinner for slow steps (running `flutter --version`,
/// fetching the matrix, asking pub.dev).
///
/// It writes to stderr and only when enabled, which callers do for an
/// interactive terminal only, so piped, `--json` and `--ci` output never
/// contain it. [stop] clears the line; call it before printing anything.
class Spinner {
  /// Creates a spinner writing to `sink` (stderr by default).
  Spinner({
    required this.enabled,
    required this.ansi,
    required this.glyphs,
    IOSink? sink,
    this.interval = const Duration(milliseconds: 80),
  }) : _sink = sink ?? stderr;

  /// Whether the spinner draws at all.
  final bool enabled;

  /// Colour helper.
  final Ansi ansi;

  /// Symbol set (supplies the animation frames).
  final Glyphs glyphs;

  /// Time between frames.
  final Duration interval;

  final IOSink _sink;
  Timer? _timer;
  var _frame = 0;
  var _message = '';

  /// Whether the spinner is currently drawn.
  bool get isRunning => _timer != null;

  /// Starts spinning next to `message`, or just changes the message when
  /// already running.
  void start(String message) {
    if (!enabled) return;
    _message = message;
    _timer ??= Timer.periodic(interval, (_) => _draw());
    _draw();
  }

  /// Stops and clears the line. Safe to call when not running.
  void stop() {
    final timer = _timer;
    if (timer == null) return;
    timer.cancel();
    _timer = null;
    _sink.write('\r\x1B[2K');
  }

  void _draw() {
    final frames = glyphs.spinner;
    final frame = frames[_frame++ % frames.length];
    _sink.write(
      '\r\x1B[2K ${ansi.fg(Tones.accent, frame)} ${ansi.dim(_message)}',
    );
  }
}
