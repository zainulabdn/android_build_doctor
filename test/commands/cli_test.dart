import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers.dart';

Future<ProcessResult> cli(List<String> args, {String? cwd}) {
  final pkg = packageRoot();
  return Process.run(Platform.resolvedExecutable, [
    'run',
    p.join(pkg, 'bin', 'android_build_doctor.dart'),
    '--offline',
    '--no-commands',
    '--no-color',
    ...args,
  ], workingDirectory: cwd ?? pkg);
}

void main() {
  test('--version', () async {
    final r = await cli(['--version']);
    expect(r.exitCode, 0);
    expect(r.stdout, startsWith('android_build_doctor '));
  });

  test('check exits 1 on errors and 0 on warnings only', () async {
    final bad = await cli(['--project', project('version_catalog'), 'check']);
    expect(bad.exitCode, 1, reason: bad.stdout.toString());
    final ok = await cli(['--project', project('kotlin_dsl'), 'check']);
    expect(ok.exitCode, 0, reason: ok.stdout.toString());
    expect(ok.stdout, contains('GD010'));
  });

  test('check --json is valid JSON with the documented shape', () async {
    final r = await cli([
      '--json',
      '--flutter-version',
      '3.47.0',
      '--project',
      project('old_groovy'),
      'check',
    ]);
    final json = jsonDecode(r.stdout.toString()) as Map<String, Object?>;
    expect(json['tool'], 'android_build_doctor');
    expect(json['versions'], isA<Map>());
    expect((json['versions'] as Map)['gradle'], {
      'value': '7.5',
      'file': 'android/gradle/wrapper/gradle-wrapper.properties',
      'line': 5,
      'raw': anything,
    });
    final findings = json['findings'] as List;
    expect(findings.first, containsPair('id', isA<String>()));
    expect(
      findings.first.keys,
      containsAll(['id', 'severity', 'file', 'line', 'message', 'fix', 'docs']),
    );
    expect((json['summary'] as Map)['exit_code'], 1);
    expect(r.exitCode, 1);
  });

  test('check --ci uses ASCII symbols and exits 1', () async {
    final r = await cli([
      '--ci',
      '--flutter-version',
      '3.47.0',
      '--project',
      project('declarative_groovy'),
      'check',
    ]);
    expect(r.exitCode, 1);
    expect(r.stdout, isNot(contains('✗')));
    expect(r.stdout, contains('XX'));
  });

  test('plugins prints the readiness verdict', () async {
    final r = await cli(['--project', project('with_plugins'), 'plugins']);
    expect(r.exitCode, 1);
    expect(
      r.stdout,
      contains('readiness: 2/3 plugins ready. Blockers: kgp_plugin.'),
    );
  });

  test('plugins asks for pub get when .dart_tool is missing', () async {
    final r = await cli(['--project', project('old_groovy'), 'plugins']);
    expect(r.exitCode, 2);
    expect(r.stderr, contains('flutter pub get'));
  });

  test('explain reads stdin with -', () async {
    final pkg = packageRoot();
    final proc = await Process.start(Platform.resolvedExecutable, [
      'run',
      p.join(pkg, 'bin', 'android_build_doctor.dart'),
      '--offline',
      '--no-color',
      'explain',
      '-',
    ], workingDirectory: pkg);
    proc.stdin.write(
      File(
        p.join(fixture('logs'), 'ge002_kotlin_extension.log'),
      ).readAsStringSync(),
    );
    await proc.stdin.close();
    final out = await proc.stdout.transform(utf8.decoder).join();
    expect(await proc.exitCode, 1);
    expect(out, contains('GE002'));
    expect(out, contains('file_picker 10.3.8'));
  });

  test('explain --json', () async {
    final r = await cli([
      '--json',
      'explain',
      p.join(fixture('logs'), 'ge001_class_file_version.log'),
    ]);
    final json = jsonDecode(r.stdout.toString()) as Map<String, Object?>;
    expect(json['matched'], isTrue);
    expect((json['explanations'] as List).first, containsPair('id', 'GE001'));
  });

  test('fix --dry-run writes nothing', () async {
    final tmp = copyFixture('version_catalog');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final wrapper = File(
      p.join(
        tmp.path,
        'android',
        'gradle',
        'wrapper',
        'gradle-wrapper.properties',
      ),
    );
    final before = wrapper.readAsStringSync();
    final r = await cli([
      '--flutter-version',
      '3.47.0',
      '--project',
      tmp.path,
      'fix',
      '--dry-run',
    ]);
    expect(r.exitCode, 0, reason: r.stderr.toString());
    expect(r.stdout, contains('+distributionUrl'));
    expect(r.stdout, contains('nothing written'));
    expect(wrapper.readAsStringSync(), before);
  });

  test('fix --yes applies, restore undoes', () async {
    final tmp = copyFixture('version_catalog');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final wrapper = File(
      p.join(
        tmp.path,
        'android',
        'gradle',
        'wrapper',
        'gradle-wrapper.properties',
      ),
    );
    final before = wrapper.readAsStringSync();
    final r = await cli([
      '--flutter-version',
      '3.47.0',
      '--project',
      tmp.path,
      'fix',
      '--yes',
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    expect(wrapper.readAsStringSync(), isNot(before));
    expect(
      Directory(
        p.join(tmp.path, 'android', '.android_build_doctor_backup'),
      ).existsSync(),
      isTrue,
    );
    final restore = await cli(['--project', tmp.path, 'restore']);
    expect(restore.exitCode, 0, reason: restore.stderr.toString());
    expect(wrapper.readAsStringSync(), before);
  });

  test('matrix prints source and date', () async {
    final r = await cli(['matrix']);
    expect(r.exitCode, 0);
    expect(r.stdout, contains('matrix 2026-09-24 (bundled)'));
    expect(r.stdout, contains('3.47'));
  });

  test('no android folder is not an error', () async {
    final tmp = Directory.systemTemp.createTempSync('abd_noandroid');
    addTearDown(() => tmp.deleteSync(recursive: true));
    File(
      p.join(tmp.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: web_only\n');
    final r = await cli(['--project', tmp.path, 'check']);
    expect(r.exitCode, 0);
    expect(r.stdout, contains('No android/ folder'));
  });

  test('not a project exits 2', () async {
    final tmp = Directory.systemTemp.createTempSync('abd_notproject');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final r = await cli(['--project', tmp.path, 'check']);
    expect(r.exitCode, 2);
  });
}
