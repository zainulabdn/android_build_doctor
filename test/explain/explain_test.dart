import 'dart:io';

import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  final explainer = Explainer(matrix: matrix);
  String log(String name) =>
      File(p.join(fixture('logs'), name)).readAsStringSync();

  test('every pattern has a log fixture that matches it and only it', () {
    final files = Directory(fixture('logs'))
        .listSync()
        .whereType<File>()
        .map((f) => p.basename(f.path))
        .where((n) => n.startsWith('ge'))
        .toList();
    for (final pattern in explainer.patterns) {
      final file = files.firstWhere(
        (f) => f.startsWith(pattern.id.toLowerCase()),
        orElse: () => fail('no fixture log for ${pattern.id}'),
      );
      final r = explainer.explain(log(file));
      expect(r.matched, isTrue, reason: '$file should match');
      expect(r.explanations.map((e) => e.id), [pattern.id], reason: file);
    }
  });

  test('GE001 derives the Java version from the class file major', () {
    final e = explainer
        .explain(log('ge001_class_file_version.log'))
        .explanations
        .single;
    expect(e.cause, contains('Java 21'));
    expect(e.fix.first, contains('supports Java 21'));
    expect(e.culprit!.isApp, isTrue);
  });

  test('GE002 names the pub-cache plugin as culprit', () {
    final r = explainer.explain(log('ge002_kotlin_extension.log'));
    expect(r.culprit!.name, 'file_picker');
    expect(r.culprit!.version, '10.3.8');
    expect(
      r.culprit!.path,
      endsWith('file_picker-10.3.8/android/build.gradle'),
    );
  });

  test('GE003 fills both versions without trailing punctuation', () {
    final e = explainer
        .explain(log('ge003_min_gradle.log'))
        .explanations
        .single;
    expect(e.cause, contains('requires Gradle 9.3.1 or newer'));
    expect(e.cause, contains('pinned to Gradle 8.7.'));
    expect(e.cause, isNot(contains('8.7..')));
  });

  test('GE005 blames the task project', () {
    final r = explainer.explain(log('ge005_kotlin_metadata.log'));
    expect(r.culprit!.name, 'geocoding_android');
    expect(r.explanations.single.cause, contains('metadata 2.1.0'));
  });

  test('GE006 blames the plugin from the pub cache path', () {
    final r = explainer.explain(log('ge006_namespace.log'));
    expect(r.culprit!.label, 'flutter_barcode_scanner 2.0.0');
  });

  test('GE010 prefers the plugin over :app in a dependency chain', () {
    final r = explainer.explain(log('ge010_jcenter.log'));
    expect(r.culprit!.name, 'old_camera_plugin');
  });

  test('GE011 extracts component and versions', () {
    final e = explainer
        .explain(log('ge011_flutter_minimum.log'))
        .explanations
        .single;
    expect(e.title, 'Flutter refuses to build with your Gradle version');
    expect(e.cause, contains('8.3.0'));
    expect(e.cause, contains('8.14.0'));
  });

  test('unknown errors fall back to the What went wrong block', () {
    final r = explainer.explain(log('unknown_error.log'));
    expect(r.matched, isFalse);
    expect(
      r.whatWentWrong,
      startsWith("Execution failed for task ':app:mergeDebugResources'."),
    );
    expect(r.culprit!.isApp, isTrue);
  });

  test('strips ANSI escapes before matching', () {
    final r = explainer.explain(
      '\x1B[31mNamespace not specified.\x1B[0m Specify a namespace',
    );
    expect(r.explanations.single.id, 'GE006');
  });

  test('errors.yaml entries are well formed', () {
    for (final pat in explainer.patterns) {
      expect(pat.id, matches(RegExp(r'^GE\d{3}$')));
      expect(pat.title, isNotEmpty, reason: pat.id);
      expect(pat.cause, isNotEmpty, reason: pat.id);
      expect(pat.fix, isNotEmpty, reason: pat.id);
      expect(pat.docs, startsWith('https://'), reason: pat.id);
    }
    expect(
      explainer.patterns.map((p) => p.id).toSet().length,
      explainer.patterns.length,
    );
  });
}
