import 'dart:io';

import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:android_build_doctor/src/data/bundled_data.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('bundled data', () {
    test('embedded YAML matches data/ files (run tool/embed_data.dart)', () {
      final pkg = packageRoot();
      expect(
        bundledMatrixYaml,
        File(p.join(pkg, 'data', 'matrix.yaml')).readAsStringSync(),
      );
      expect(
        bundledErrorsYaml,
        File(p.join(pkg, 'data', 'errors.yaml')).readAsStringSync(),
      );
    });

    test('package version constant matches pubspec.yaml', () {
      final pkg = packageRoot();
      final pubspec = File(p.join(pkg, 'pubspec.yaml')).readAsStringSync();
      expect(pubspec, contains('version: $packageVersion\n'));
    });
  });

  group('CompatMatrix', () {
    test('parses the bundled matrix', () {
      expect(matrix.schemaVersion, 1);
      expect(matrix.source, 'bundled');
      expect(matrix.latestFlutter, '3.47');
      expect(matrix.flutterSeries.first, '3.47');
      final r = matrix.flutter['3.47']!;
      expect(r.verified.agp, '9.1.0');
      expect(r.verified.gradle, '9.3.1');
      expect(r.verified.kgp, '2.4.0');
      expect(r.verified.java, '17');
      expect(r.minimums.gradle, '8.14.0');
      expect(r.defaults.minSdk, 24);
      expect(r.builtInKotlinSupported, isTrue);
      expect(r.legacyKgpFlag, isTrue);
      expect(matrix.flutter['3.44']!.builtInKotlinSupported, isFalse);
      expect(matrix.flutter['3.41']!.legacyKgpFlag, isFalse);
    });

    test('releaseFor falls back to the nearest older series', () {
      expect(matrix.releaseFor('3.47.1')!.series, '3.47');
      expect(matrix.releaseFor('3.50.0')!.series, '3.47');
      expect(matrix.releaseFor('3.45.0')!.series, '3.44');
      expect(matrix.releaseFor('3.36.2')!.series, '3.35');
      expect(matrix.releaseFor('2.0.0'), isNull);
      expect(matrix.releaseFor(null), isNull);
      expect(matrix.hasExactRelease('3.50.0'), isFalse);
    });

    test('AGP lookups', () {
      expect(matrix.minGradleForAgp('9.1.0'), '9.3.1');
      expect(matrix.minGradleForAgp('9.1.2'), '9.3.1');
      expect(matrix.minGradleForAgp('8.9.1'), '8.11.1');
      expect(matrix.minGradleForAgp('7.3.0'), '7.4');
      expect(matrix.minGradleForAgp('1.0.0'), isNull);
      expect(matrix.minJdkForAgp('8.1.0'), 17);
      expect(matrix.minJdkForAgp('7.4.2'), 11);
    });

    test('Gradle/Java lookups', () {
      expect(matrix.maxJavaForGradle('8.3'), 20);
      expect(matrix.maxJavaForGradle('8.7'), 21);
      expect(matrix.maxJavaForGradle('7.5'), 18);
      expect(matrix.maxJavaForGradle('9.3.1'), 25);
      expect(matrix.maxJavaForGradle('1.0'), isNull);
      expect(matrix.minJavaForGradle('9.0'), 17);
      expect(matrix.minJavaForGradle('8.14'), 8);
      expect(matrix.minGradleForJava(21), '8.5');
      expect(matrix.minGradleForJava(25), '9.1.0');
      expect(matrix.javaForClassFile(65), '21');
      expect(matrix.javaForClassFile(99), '55');
    });
  });

  group('MatrixLoader', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('abd_matrix'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String yamlWithDate(String date) =>
        bundledMatrixYaml.replaceFirst('updated: 2026-09-24', 'updated: $date');

    test('uses remote when it is newer and caches it', () async {
      final client = MockClient(
        (_) async => http.Response(yamlWithDate('2027-01-01'), 200),
      );
      final loader = MatrixLoader(client: client, cacheDir: tmp.path);
      final m = await loader.load();
      expect(m.source, 'remote');
      expect(m.updated, '2027-01-01');
      expect(File(p.join(tmp.path, 'matrix.yaml')).existsSync(), isTrue);

      final again = await MatrixLoader(
        client: client,
        cacheDir: tmp.path,
      ).load();
      expect(again.source, 'cache');
    });

    test('falls back to bundled when remote fails or is older', () async {
      final failing = MockClient((_) async => http.Response('nope', 500));
      final m = await MatrixLoader(client: failing, cacheDir: tmp.path).load();
      expect(m.source, 'bundled');

      final older = MockClient(
        (_) async => http.Response(yamlWithDate('2020-01-01'), 200),
      );
      final m2 = await MatrixLoader(client: older, cacheDir: tmp.path).load();
      expect(m2.source, 'bundled');
    });

    test('offline never touches the network', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response(yamlWithDate('2027-01-01'), 200);
      });
      final m = await MatrixLoader(
        client: client,
        cacheDir: tmp.path,
      ).load(offline: true);
      expect(m.source, 'bundled');
      expect(calls, 0);
    });

    test('times out slow remotes', () async {
      final slow = MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response(yamlWithDate('2027-01-01'), 200);
      });
      final m = await MatrixLoader(
        client: slow,
        cacheDir: tmp.path,
        timeout: const Duration(milliseconds: 50),
      ).load();
      expect(m.source, 'bundled');
    });
  });
}
