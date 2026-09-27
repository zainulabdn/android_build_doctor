import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:test/test.dart';

Painter painter({
  Glyphs glyphs = Glyphs.unicode,
  ColorDepth depth = ColorDepth.trueColor,
  int width = 60,
  List<String>? sink,
}) => Painter(
  out: (l) => sink?.add(l),
  ansi: Ansi(depth: depth),
  glyphs: glyphs,
  width: width,
);

void main() {
  test('panels are exactly as wide as asked, in both glyph sets', () {
    for (final glyphs in [Glyphs.unicode, Glyphs.ascii]) {
      final p = painter(glyphs: glyphs);
      final lines = p.panelLines([
        'short',
        '${p.symbol(Severity.error)} ${'long text ' * 10}',
        '',
      ], title: 'Toolchain');
      expect(lines, hasLength(5));
      for (final l in lines) {
        expect(visibleWidth(l), 60, reason: stripAnsi(l));
      }
      expect(
        stripAnsi(lines.first),
        startsWith('${glyphs.topLeft}${glyphs.horizontal} Toolchain '),
      );
    }
  });

  test('badges are 7 cells and right-align their label', () {
    final p = painter(depth: ColorDepth.none);
    expect(p.badge(Severity.error), ' ERROR ');
    expect(p.badge(Severity.warning), '  WARN ');
    expect(p.badge(Severity.info), '  INFO ');
  });

  test('the meter is full only when complete and empty only at zero', () {
    final p = painter(depth: ColorDepth.none);
    int filled(String m) => '━'.allMatches(m).length;
    expect(p.meter(3, 3, 20, Tones.good), '━' * 20);
    expect(filled(p.meter(39, 40, 20, Tones.warning)), 19);
    expect(filled(p.meter(1, 40, 20, Tones.warning)), 1);
    expect(filled(p.meter(0, 40, 20, Tones.warning)), 0);
    expect(visibleWidth(p.meter(2, 3, 20, Tones.warning)), 20);
    final ascii = painter(depth: ColorDepth.none, glyphs: Glyphs.ascii);
    expect(ascii.meter(1, 2, 4, Tones.good), '##..');
  });

  test('counts pluralise and are null without findings', () {
    final p = painter(depth: ColorDepth.none);
    const e = Finding(id: 'X', severity: Severity.error, message: 'm');
    const w = Finding(id: 'Y', severity: Severity.warning, message: 'm');
    expect(p.counts(const []), isNull);
    expect(p.counts(const [e, w, w]), '✗ 1 error  ▲ 2 warnings');
  });

  test('a finding wraps under its message and lines up the rest', () {
    final lines = <String>[];
    final p = painter(depth: ColorDepth.none, width: 50, sink: lines);
    p.finding(
      const Finding(
        id: 'GD002',
        severity: Severity.error,
        message:
            'AGP 9.1.0 needs Gradle >= 9.3.1, but the wrapper uses Gradle 8.7.',
        fix: 'Set distributionUrl to gradle-9.3.1-all.zip.',
        source: SourceRef(
          'android/gradle/wrapper/gradle-wrapper.properties',
          5,
        ),
      ),
    );
    expect(lines.first, startsWith(' ERROR  GD002  AGP 9.1.0 needs'));
    expect(lines[1], startsWith(' ' * 15));
    expect(
      lines,
      contains('        android/gradle/wrapper/gradle-wrapper.properties:5'),
    );
    final fix = lines.indexWhere((l) => l.startsWith('        fix  '));
    expect(fix, greaterThan(0));
    expect(lines.last, startsWith(' ' * 13), reason: 'wrapped under the fix');
  });

  test('step rows keep two spaces after a long command', () {
    final p = painter(depth: ColorDepth.none);
    expect(p.step('abc', 'does x', commandWidth: 6), '→ abc   does x');
    expect(
      p.step('a_very_long_command', 'x', commandWidth: 6),
      '→ a_very_long_command  x',
    );
  });
}
