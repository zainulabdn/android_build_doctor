import 'dart:io';

import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers.dart';

/// Renders with `draw` and returns the printed lines.
List<String> render(
  void Function(Painter painter) draw, {
  Glyphs glyphs = Glyphs.unicode,
  ColorDepth depth = ColorDepth.trueColor,
  int width = 80,
}) {
  final lines = <String>[];
  draw(
    Painter(
      out: lines.add,
      ansi: Ansi(depth: depth),
      glyphs: glyphs,
      width: width,
    ),
  );
  return lines;
}

/// Every panel line (a line that starts with a box edge) is `width` wide.
void expectAlignedPanels(List<String> lines, Glyphs g, {int width = 80}) {
  final edges = {g.topLeft, g.vertical, g.bottomLeft};
  for (final l in lines.map(stripAnsi)) {
    if (l.isEmpty || !edges.contains(l[0])) continue;
    expect(visibleWidth(l), width, reason: l);
  }
}

Future<List<String>> checkReport(
  String name, {
  String flutter = '3.47.1',
  Glyphs glyphs = Glyphs.unicode,
  ColorDepth depth = ColorDepth.trueColor,
}) async {
  final s = await snapshotOf(name, flutter: flutter, java: 17);
  final ctx = RuleContext(snapshot: s, matrix: matrix);
  return render(
    (painter) => ConsoleReporter.withPainter(painter)
      ..header('0.0.0', matrix)
      ..report(
        snapshot: s,
        matrix: matrix,
        findings: runRules(projectRules, ctx),
        release: ctx.release,
      ),
    glyphs: glyphs,
    depth: depth,
  );
}

void main() {
  group('check report', () {
    test('a healthy project gets a green card and no problems', () async {
      final lines = (await checkReport('healthy_347')).map(stripAnsi).toList();
      expect(lines.join('\n'), contains('No problems found.'));
      expect(lines.join('\n'), contains('Everything matches Flutter 3.47.'));
      expect(lines.any((l) => l.startsWith(' ERROR')), isFalse);
    });

    test('rows summarise, problems carry location and fix', () async {
      final text = (await checkReport(
        'version_catalog',
      )).map(stripAnsi).join('\n');
      expect(
        text,
        contains('│ ✗ Gradle           8.10      needs ≥ 8.11.1 for AGP 8.9.1'),
      );
      expect(text, contains(' ERROR  GD002  AGP 8.9.1 needs Gradle >= 8.11.1'));
      expect(
        text,
        contains('        android/gradle/wrapper/gradle-wrapper.properties:5'),
      );
      expect(text, contains('fixable automatically'));
      expect(text, contains('→ android_build_doctor fix'));
    });

    test('panels stay aligned in both glyph sets', () async {
      for (final g in [Glyphs.unicode, Glyphs.ascii]) {
        for (final name in ['old_groovy', 'with_plugins', 'kotlin_dsl']) {
          expectAlignedPanels(await checkReport(name, glyphs: g), g);
        }
      }
    });

    test('ASCII without colour is pure ASCII with no escape codes', () async {
      final lines = await checkReport(
        'old_groovy',
        glyphs: Glyphs.ascii,
        depth: ColorDepth.none,
      );
      final text = lines.join('\n');
      expect(text.codeUnits.every((c) => c < 128), isTrue, reason: text);
      expect(text, isNot(contains('\x1B')));
    });
  });

  group('plugins report', () {
    test('shows the meter, the blockers and the worst plugin first', () async {
      final s = await snapshotOf('with_plugins', flutter: '3.47.0');
      final findings = runRules(
        pluginRules,
        RuleContext(snapshot: s, matrix: matrix),
      );
      final lines = render(
        (painter) =>
            PluginsReporter(painter).report(snapshot: s, findings: findings),
      );
      final text = lines.map(stripAnsi).join('\n');
      expect(text, contains('2/3 ready'));
      expect(text, contains('1 blocker: kgp_plugin'));
      expect(
        text.indexOf('no_namespace_plugin 0.5.0'),
        lessThan(text.indexOf('kgp_plugin 1.0.0')),
        reason: 'the plugin with an error comes first',
      );
      expect(text, contains('GP001  Still applies the Kotlin Gradle Plugin.'));
      expectAlignedPanels(lines, Glyphs.unicode);
    });
  });

  group('explain report', () {
    String log(String name) =>
        File(p.join(fixture('logs'), name)).readAsStringSync();

    test('matched patterns get badge, culprit, cause and numbered fixes', () {
      final result = Explainer(
        matrix: matrix,
      ).explain(log('ge002_kotlin_extension.log'));
      final text = render(
        (painter) => ExplainReporter(painter).report(result),
      ).map(stripAnsi).join('\n');
      expect(text, contains(' ERROR  GE002  A Kotlin plugin is applied twice'));
      expect(text, contains('culprit  file_picker 10.3.8'));
      expect(text, contains('fix      1. Run `android_build_doctor plugins`'));
      expect(text, contains('1 known problem in this log'));
    });

    test('notices from a successful build are warnings', () {
      final result = Explainer(
        matrix: matrix,
      ).explain(log('ge012_flutter_soon_dropped.log'));
      expect(result.explanations.single.severity, Severity.warning);
      final text = render(
        (painter) => ExplainReporter(painter).report(result),
      ).map(stripAnsi).join('\n');
      expect(text, contains('  WARN  GE012'));
    });
  });

  group('fix report', () {
    test('diffs show old and new line numbers', () {
      final lines = render(
        (painter) => FixReporter(
          painter,
        ).diff('f.txt', 'a\nb\nc\ndelete me\nd\n', 'a\nB\nc\nd\n'),
        depth: ColorDepth.none,
      );
      expect(lines, contains(' 2    -b'));
      expect(lines, contains('   2  +B'));
      expect(lines, contains(' 4    -delete me'));
      expect(lines, contains(' 5 4   d'));
    });

    test('the plan groups identical edits and keeps the rationale', () async {
      final tmp = copyFixture('old_groovy');
      addTearDown(() => tmp.deleteSync(recursive: true));
      var s = await ProjectDetector(
        run: noProcess,
        environment: const {},
      ).detect(tmp.path, scanPlugins: true);
      s = s.copyWith(flutterVersion: const Detected('3.47.0'));
      final ctx = RuleContext(snapshot: s, matrix: matrix);
      final plan = FixPlanner(
        snapshot: s,
        matrix: matrix,
        findings: [
          ...runRules(projectRules, ctx),
          ...runRules(pluginRules, ctx),
        ],
        release: ctx.release,
      ).plan();
      final lines = render(
        (painter) => FixReporter(painter).plan(plan, files: 3),
      );
      final text = lines.map(stripAnsi).join('\n');
      expect(text, contains('Plan · 6 edits in 3 files'));
      expect(text, contains('GD016  Gradle 7.5 → 8.14'));
      expect(text, contains('(2 lines)'));
      expect(text, contains('Plugins could not be scanned'));
      expectAlignedPanels(lines, Glyphs.unicode);
    });
  });

  test('matrix report puts the AGP and Gradle tables side by side', () {
    final lines = render((painter) => MatrixReporter(painter).report(matrix));
    final text = lines.map(stripAnsi).join('\n');
    expect(text, contains('╭─ AGP needs '));
    expect(text, contains('╭─ Gradle runs on '));
    expect(
      lines
          .map(stripAnsi)
          .any((l) => l.contains('AGP needs') && l.contains('Gradle runs on')),
      isTrue,
    );
    expect(text, contains('3.47     17    2.4.0'));
  });
}
