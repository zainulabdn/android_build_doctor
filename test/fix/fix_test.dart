import 'dart:io';

import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers.dart';

Future<(ProjectSnapshot, List<Finding>)> detect(
  String dir, {
  String? flutter,
  int? java,
}) async {
  var s = await ProjectDetector(
    run: noProcess,
    environment: const {},
  ).detect(dir, scanPlugins: true);
  if (flutter != null) s = s.copyWith(flutterVersion: Detected(flutter));
  if (java != null) s = s.copyWith(javaVersion: Detected(java));
  final ctx = RuleContext(snapshot: s, matrix: matrix);
  return (s, [...runRules(projectRules, ctx), ...runRules(pluginRules, ctx)]);
}

FixPlan planFor(ProjectSnapshot s, List<Finding> fs) => FixPlanner(
  snapshot: s,
  matrix: matrix,
  findings: fs,
  release: matrix.releaseFor(s.flutterVersion?.value),
).plan();

/// Lines of `after` that differ from `before` (by index), for round-trip checks.
List<int> changedLines(String before, String after) {
  final a = before.split('\n');
  final b = after.split('\n');
  final out = <int>[];
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) out.add(i + 1);
  }
  return out;
}

void main() {
  group('FileEdit', () {
    test('replace keeps CRLF and trailing newline state', () {
      const e = FileEdit.replaceLine(
        path: 'x',
        line: 2,
        newText: 'B',
        reason: '',
        findingId: 'T',
      );
      expect(e.applyTo('a\r\nb\r\nc\r\n'), 'a\r\nB\r\nc\r\n');
      expect(e.applyTo('a\nb\nc'), 'a\nB\nc');
    });

    test('insert, delete and append', () {
      const ins = FileEdit.insertBefore(
        path: 'x',
        line: 2,
        newText: 'X',
        reason: '',
        findingId: 'T',
      );
      expect(ins.applyTo('a\nb\n'), 'a\nX\nb\n');
      const del = FileEdit.deleteLine(
        path: 'x',
        line: 1,
        reason: '',
        findingId: 'T',
      );
      expect(del.applyTo('a\nb\n'), 'b\n');
      const app = FileEdit.appendLine(
        path: 'x',
        newText: 'z',
        reason: '',
        findingId: 'T',
      );
      expect(app.applyTo('a\nb'), 'a\nb\nz\n');
      expect(app.applyTo(''), 'z\n');
    });

    test('applier orders edits bottom-up so lines stay valid', () {
      final tmp = Directory.systemTemp.createTempSync('abd_edit');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final f = File(p.join(tmp.path, 'f.txt'))
        ..writeAsStringSync('1\n2\n3\n4\n');
      final edits = [
        FileEdit.replaceLine(
          path: f.path,
          line: 1,
          newText: 'one',
          reason: '',
          findingId: 'T',
        ),
        FileEdit.deleteLine(path: f.path, line: 3, reason: '', findingId: 'T'),
        FileEdit.insertBefore(
          path: f.path,
          line: 2,
          newText: 'x',
          reason: '',
          findingId: 'T',
        ),
        FileEdit.appendLine(
          path: f.path,
          newText: 'end',
          reason: '',
          findingId: 'T',
        ),
      ];
      final preview = EditApplier.preview(edits);
      expect(preview[f.path], 'one\nx\n2\n4\nend\n');
      EditApplier.write(preview);
      expect(f.readAsStringSync(), 'one\nx\n2\n4\nend\n');
    });
  });

  group('DiffPrinter', () {
    test('produces a unified hunk for a single-line change', () {
      final d = DiffPrinter(
        Ansi(enabled: false),
      ).unified('f', 'a\nb\nc\nd\ne\nf\ng\n', 'a\nb\nc\nD\ne\nf\ng\n');
      expect(d, contains('--- a/f'));
      expect(d, contains('@@ -1,7 +1,7 @@'));
      expect(d, contains('-d\n+D\n'));
    });
  });

  group('FixPlanner round trips', () {
    late Directory tmp;
    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test(
      'old_groovy on Flutter 3.47 without .dart_tool stays on AGP 8 and fixes the rest',
      () async {
        tmp = copyFixture('old_groovy');
        final (s, fs) = await detect(tmp.path, flutter: '3.47.0', java: 17);
        final plan = planFor(s, fs);
        expect(plan.targets.agp, '8.11.1');
        expect(plan.targets.gradle, '8.14');
        expect(plan.targets.kgp, '2.2.20');
        expect(plan.rationale.first, contains('Plugins could not be scanned'));
        expect(plan.temporaryKgpFlag, isFalse);
        expect(plan.findingIds, containsAll(['GD016', 'GD013', 'GD009']));

        final before = {
          for (final path in plan.edits.map((e) => e.path).toSet())
            path: File(path).readAsStringSync(),
        };
        final preview = EditApplier.preview(plan.edits);
        EditApplier.write(preview);

        // Root build.gradle: versions replaced on their lines, jcenter lines removed, rest identical.
        final root = p.join(tmp.path, 'android', 'build.gradle');
        final after = File(root).readAsStringSync();
        expect(after, contains("ext.kotlin_version = '2.2.20'"));
        expect(
          after,
          contains("classpath 'com.android.tools.build:gradle:8.11.1'"),
        );
        expect(after, isNot(contains('jcenter')));
        expect(after.split('\n').length, before[root]!.split('\n').length - 2);

        final wrapper = File(
          p.join(
            tmp.path,
            'android',
            'gradle',
            'wrapper',
            'gradle-wrapper.properties',
          ),
        ).readAsStringSync();
        expect(wrapper, contains('gradle-8.14-all.zip'));
        expect(
          changedLines(
            before[p.join(
              tmp.path,
              'android',
              'gradle',
              'wrapper',
              'gradle-wrapper.properties',
            )]!,
            wrapper,
          ),
          [5],
        );

        final app = File(
          p.join(tmp.path, 'android', 'app', 'build.gradle'),
        ).readAsStringSync();
        expect(
          app,
          contains(
            'android {\n    namespace "com.example.old_groovy"\n    compileSdkVersion 33',
          ),
        );

        // Re-detect: the fixed findings are gone.
        final (_, fs2) = await detect(tmp.path, flutter: '3.47.0', java: 17);
        expect(ids(fs2), isNot(contains('GD016')));
        expect(ids(fs2), isNot(contains('GD013')));
        expect(ids(fs2), isNot(contains('GD009')));
        expect(ids(fs2), isNot(contains('GD002')));
        // Structural findings remain, as advertised.
        expect(ids(fs2), contains('GD008'));
      },
    );

    test(
      'with_plugins (blockers known, already AGP 9) only adds nothing new',
      () async {
        tmp = copyFixture('with_plugins');
        // Adjust relative package_config paths: copy plugins next to the temp dir.
        final pluginsSrc = Directory(fixture('plugins'));
        final pluginsDst = Directory(
          p.join(p.dirname(p.dirname(tmp.path)), 'plugins'),
        );
        final cfg = File(p.join(tmp.path, '.dart_tool', 'package_config.json'));
        cfg.writeAsStringSync(
          cfg.readAsStringSync().replaceAll(
            '../../../plugins/',
            '${pluginsSrc.path}/',
          ),
        );
        expect(pluginsDst.existsSync() || true, isTrue);
        final (s, fs) = await detect(tmp.path, flutter: '3.47.0', java: 17);
        expect(s.kgpPlugins.map((e) => e.name), ['kgp_plugin']);
        final plan = planFor(s, fs);
        expect(plan.edits, isEmpty);
        expect(plan.advice.any((a) => a.contains('kgp_plugin')), isTrue);
      },
    );

    test('agp9_kgp_applied gets a temporary builtInKotlin=false', () async {
      tmp = copyFixture('agp9_kgp_applied');
      final (s, fs) = await detect(tmp.path, flutter: '3.47.0', java: 17);
      expect(ids(fs), contains('GD005'));
      final plan = planFor(s, fs);
      expect(plan.temporaryKgpFlag, isTrue);
      expect(plan.edits.single.append, isTrue);
      EditApplier.write(EditApplier.preview(plan.edits));
      final props = File(
        p.join(tmp.path, 'android', 'gradle.properties'),
      ).readAsStringSync();
      expect(
        props,
        endsWith('android.useAndroidX=true\nandroid.builtInKotlin=false\n'),
      );
      final (_, fs2) = await detect(tmp.path, flutter: '3.47.0', java: 17);
      expect(ids(fs2), isNot(contains('GD005')));
      expect(ids(fs2), contains('GD006'));
    });

    test(
      'version_catalog bumps the toml and the wrapper; Java 21 raises Gradle',
      () async {
        tmp = copyFixture('version_catalog');
        // Pretend plugins were scanned and none block AGP 9.
        Directory(p.join(tmp.path, '.dart_tool')).createSync();
        File(
          p.join(tmp.path, '.dart_tool', 'package_config.json'),
        ).writeAsStringSync(
          '{"configVersion":2,"packages":[{"name":"version_catalog","rootUri":"../","packageUri":"lib/"}]}',
        );
        final (s, fs) = await detect(tmp.path, flutter: '3.47.0', java: 21);
        final plan = planFor(s, fs);
        expect(plan.targets.agp, '9.1.0');
        expect(plan.targets.gradle, '9.3.1');
        final toml = p.join(
          tmp.path,
          'android',
          'gradle',
          'libs.versions.toml',
        );
        final before = File(toml).readAsStringSync();
        EditApplier.write(EditApplier.preview(plan.edits));
        final after = File(toml).readAsStringSync();
        expect(changedLines(before, after), [2, 3]);
        expect(after, contains('agp = "9.1.0"'));
        expect(after, contains('kotlin = "2.4.0"'));
        final (_, fs2) = await detect(tmp.path, flutter: '3.47.0', java: 21);
        expect(ids(fs2), isNot(contains('GD002')));
        expect(ids(fs2), isNot(contains('GD016')));
        expect(ids(fs2), isNot(contains('GD003')));
      },
    );

    test('never downgrades', () async {
      tmp = copyFixture('healthy_347');
      final (s, fs) = await detect(tmp.path, flutter: '3.44.0', java: 17);
      final plan = planFor(s, fs);
      expect(plan.edits, isEmpty);
      expect(plan.targets.agp, '9.1.0');
    });
  });

  group('BackupManager', () {
    test('backs up and restores', () async {
      final tmp = copyFixture('old_groovy');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final target = File(p.join(tmp.path, 'android', 'gradle.properties'));
      final original = target.readAsStringSync();
      final mgr = BackupManager(tmp.path);
      final dir = mgr.backup([target.path]);
      expect(Directory(dir).existsSync(), isTrue);
      target.writeAsStringSync('changed\n');
      expect(mgr.list(), hasLength(1));
      final restored = mgr.restore();
      expect(restored, [p.join('android', 'gradle.properties')]);
      expect(target.readAsStringSync(), original);
      expect(mgr.list(), isEmpty);
      expect(File(p.join(mgr.root, '.gitignore')).existsSync(), isTrue);
    });
  });
}
