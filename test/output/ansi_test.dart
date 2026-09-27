import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:test/test.dart';

void main() {
  group('Ansi.detectDepth', () {
    ColorDepth detect(Map<String, String> env, {bool terminal = true}) =>
        Ansi.detectDepth(env, isTerminal: terminal);

    test('is off for pipes, TERM=dumb and a non-empty NO_COLOR', () {
      expect(detect({}, terminal: false), ColorDepth.none);
      expect(detect({'TERM': 'dumb'}), ColorDepth.none);
      expect(detect({'NO_COLOR': '1'}), ColorDepth.none);
    });

    test('ignores an empty NO_COLOR, as the spec says', () {
      expect(detect({'NO_COLOR': ''}), ColorDepth.ansi16);
    });

    test('reads 24-bit and 256-colour hints', () {
      expect(detect({'COLORTERM': 'truecolor'}), ColorDepth.trueColor);
      expect(detect({'TERM_PROGRAM': 'iTerm.app'}), ColorDepth.trueColor);
      expect(detect({'WT_SESSION': 'abc'}), ColorDepth.trueColor);
      expect(detect({'TERM': 'xterm-256color'}), ColorDepth.ansi256);
      expect(detect({'TERM_PROGRAM': 'Apple_Terminal'}), ColorDepth.ansi256);
      expect(detect({'TERM': 'xterm'}), ColorDepth.ansi16);
    });

    test('FORCE_COLOR wins, even without a terminal', () {
      expect(
        detect({'FORCE_COLOR': '3'}, terminal: false),
        ColorDepth.trueColor,
      );
      expect(detect({'FORCE_COLOR': '2'}, terminal: false), ColorDepth.ansi256);
      expect(detect({'FORCE_COLOR': '1'}, terminal: false), ColorDepth.ansi16);
      expect(detect({'FORCE_COLOR': '0'}), ColorDepth.none);
    });
  });

  group('Tone.xterm256', () {
    test('maps to the nearest cube or grey entry', () {
      expect(const Tone(0xFFFFFF, 97).xterm256, 231);
      expect(const Tone(0x000000, 30).xterm256, 16);
      expect(const Tone(0xFF0000, 31).xterm256, 196);
      expect(const Tone(0x0B0B0B, 30).xterm256, 232);
      expect(const Tone(0x808080, 90).xterm256, 244);
    });
  });

  group('Ansi', () {
    test('emits nothing when disabled', () {
      final a = Ansi(enabled: false);
      expect(a.fg(Tones.error, 'x'), 'x');
      expect(a.badge(' ERROR ', Tones.errorFill, Tones.white), ' ERROR ');
      expect(a.bold('x'), 'x');
      expect(a.theme(31, 'x'), 'x');
    });

    test('uses the right codes at each depth', () {
      const tone = Tone(0xD94545, 31);
      expect(
        Ansi(depth: ColorDepth.trueColor).fg(tone, 'x'),
        '\x1B[38;2;217;69;69mx\x1B[39m',
      );
      expect(
        Ansi(depth: ColorDepth.ansi256).fg(tone, 'x'),
        '\x1B[38;5;${tone.xterm256}mx\x1B[39m',
      );
      expect(Ansi(depth: ColorDepth.ansi16).fg(tone, 'x'), '\x1B[31mx\x1B[39m');
      expect(Ansi(depth: ColorDepth.ansi16).bg(tone, 'x'), '\x1B[41mx\x1B[49m');
    });

    test('closes only what it opened, so styles nest', () {
      final a = Ansi(depth: ColorDepth.ansi16);
      expect(
        a.fg(Tones.good, 'ok ${a.bold('now')}'),
        '\x1B[32mok \x1B[1mnow\x1B[22m\x1B[39m',
      );
    });
  });
}
