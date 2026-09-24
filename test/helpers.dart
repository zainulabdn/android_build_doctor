import 'dart:io';

import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:path/path.dart' as p;

/// Absolute path of `test/fixtures/<sub>`.
String fixture(String sub) {
  // Works whether tests run from the package root or the test directory.
  var dir = Directory.current.path;
  if (!Directory(p.join(dir, 'test', 'fixtures')).existsSync()) {
    dir = p.dirname(dir);
  }
  return p.normalize(p.join(dir, 'test', 'fixtures', sub));
}

/// Normalises CRLF to LF so byte-exact expectations hold on Windows.
String lf(String s) => s.replaceAll('\r\n', '\n');

/// Absolute path of the package root.
String packageRoot() => p.dirname(p.dirname(fixture('')));

/// Absolute path of a project fixture.
String project(String name) => fixture(p.join('projects', name));

/// The bundled matrix.
final CompatMatrix matrix = MatrixLoader().bundled;

/// Detects a project fixture without running external commands, optionally
/// pretending to run on `flutter` with `java`.
Future<ProjectSnapshot> snapshotOf(
  String name, {
  String? flutter,
  int? java,
  bool scanPlugins = true,
}) async {
  var s = await ProjectDetector(
    run: noProcess,
    environment: const {},
  ).detect(project(name), scanPlugins: scanPlugins);
  if (flutter != null) {
    s = s.copyWith(
      flutterVersion: Detected(flutter),
      flutterVersionSource: 'test',
    );
  }
  if (java != null) {
    s = s.copyWith(
      javaVersion: Detected(java),
      javaSource: 'test',
      javaHome: '/jdk',
    );
  }
  return s;
}

/// Evaluates the project rules for a fixture.
Future<List<Finding>> findingsFor(
  String name, {
  String? flutter,
  int? java,
  String? target,
  Iterable<Rule>? rules,
}) async {
  final s = await snapshotOf(name, flutter: flutter, java: java);
  final ctx = RuleContext(snapshot: s, matrix: matrix, targetFlutter: target);
  return runRules(rules ?? projectRules, ctx);
}

/// Ids of `findings`.
Set<String> ids(List<Finding> findings) => findings.map((f) => f.id).toSet();

/// Copies a fixture project into a temporary directory and returns its path.
Directory copyFixture(String name) {
  final tmp = Directory.systemTemp.createTempSync('abd_$name');
  final src = Directory(project(name));
  for (final entity in src.listSync(recursive: true)) {
    final rel = p.relative(entity.path, from: src.path);
    if (entity is Directory) {
      Directory(p.join(tmp.path, rel)).createSync(recursive: true);
    } else if (entity is File) {
      File(p.join(tmp.path, rel)).parent.createSync(recursive: true);
      entity.copySync(p.join(tmp.path, rel));
    }
  }
  return tmp;
}
