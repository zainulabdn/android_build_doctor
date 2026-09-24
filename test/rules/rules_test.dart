import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:test/test.dart';

import '../helpers.dart';

Finding one(List<Finding> fs, String id) => fs.singleWhere((f) => f.id == id);
List<Finding> all(List<Finding> fs, String id) =>
    fs.where((f) => f.id == id).toList();

void main() {
  group('healthy project', () {
    test('has no findings on Flutter 3.47 with Java 17', () async {
      final fs = await findingsFor('healthy_347', flutter: '3.47.1', java: 17);
      expect(fs, isEmpty);
    });

    test('has no findings when Flutter is unknown', () async {
      expect(await findingsFor('healthy_347'), isEmpty);
    });
  });

  group('GD001 Java too old', () {
    test('errors below Flutter minimum', () async {
      final fs = await findingsFor('healthy_347', flutter: '3.47.0', java: 11);
      final f = one(fs, 'GD001');
      expect(f.severity, Severity.error);
      expect(f.message, contains('Java 11 is too old'));
      expect(f.data['min_java'], 17);
    });

    test('errors below AGP minimum even when Flutter has no minimum', () async {
      final fs = await findingsFor('kotlin_dsl', flutter: '3.32.0', java: 11);
      expect(one(fs, 'GD001').message, contains('AGP 8.7.3 requires JDK 17'));
    });

    test('warns below Flutter warn threshold', () async {
      // 3.35: error below 11, warn below 17; AGP 7.3 needs 11.
      final fs = await findingsFor('old_groovy', flutter: '3.35.0', java: 11);
      expect(one(fs, 'GD001').severity, Severity.warning);
    });

    test('silent when Java is fine', () async {
      final fs = await findingsFor('healthy_347', flutter: '3.47.0', java: 21);
      expect(all(fs, 'GD001'), isEmpty);
    });
  });

  group('GD002 Gradle below AGP minimum', () {
    test('fires for version_catalog (AGP 8.9.1 on Gradle 8.10)', () async {
      final fs = await findingsFor('version_catalog');
      final f = one(fs, 'GD002');
      expect(f.severity, Severity.error);
      expect(f.autoFixable, isTrue);
      expect(f.data['min_gradle'], '8.11.1');
      expect(
        f.source.toString(),
        'android/gradle/wrapper/gradle-wrapper.properties:5',
      );
    });
  });

  group('GD003 Java too new for Gradle', () {
    test('Java 21 on Gradle 8.3', () async {
      final fs = await findingsFor('declarative_groovy', java: 21);
      final f = one(fs, 'GD003');
      expect(f.severity, Severity.error);
      expect(f.message, contains('major version 65'));
      expect(f.data['min_gradle_for_java'], '8.5');
    });

    test('Java 17 on Gradle 7.5 is fine', () async {
      final fs = await findingsFor('old_groovy', java: 17);
      expect(all(fs, 'GD003'), isEmpty);
    });
  });

  group('GD004 / GD016 versions vs Flutter', () {
    test('GD016 errors below hard minimums and suppresses GD004', () async {
      final fs = await findingsFor('declarative_groovy', flutter: '3.47.0');
      final g16 = all(fs, 'GD016');
      expect(
        g16.map((f) => f.data['component']),
        containsAll(['gradle', 'agp', 'kgp']),
      );
      expect(all(fs, 'GD004'), isEmpty);
      expect(g16.first.autoFixable, isTrue);
    });

    test('GD004 warns when above minimum but below verified', () async {
      // kotlin_dsl: Gradle 8.12 / AGP 8.7.3 / KGP 2.1.0 on 3.41 (min 8.3/8.1.1/1.8.10, verified 8.14/8.11.1/2.2.20)
      final fs = await findingsFor('kotlin_dsl', flutter: '3.41.0');
      final g4 = all(fs, 'GD004');
      expect(
        g4.map((f) => f.data['component']),
        containsAll(['gradle', 'agp', 'kgp']),
      );
      expect(g4.every((f) => f.severity == Severity.warning), isTrue);
      expect(all(fs, 'GD016'), isEmpty);
    });

    test('nothing when everything matches verified', () async {
      final fs = await findingsFor('kotlin_dsl', flutter: '3.32.0');
      expect(all(fs, 'GD004'), isEmpty);
      expect(all(fs, 'GD016'), isEmpty);
    });

    test('--target evaluates against the target release', () async {
      final fs = await findingsFor(
        'declarative_groovy',
        flutter: '3.24.0',
        target: '3.44.0',
      );
      expect(
        all(fs, 'GD016').map((f) => f.data['minimum']),
        containsAll(['8.7.0', '8.6.0', '2.0.0']),
      );
    });
  });

  group('GD005 / GD006 / GD007 built-in Kotlin', () {
    test(
      'GD005 errors when app applies kotlin-android on AGP 9 without the flag',
      () async {
        final fs = await findingsFor('agp9_kgp_applied', flutter: '3.47.0');
        final f = one(fs, 'GD005');
        expect(f.severity, Severity.error);
        expect(f.autoFixable, isTrue);
        expect(f.source.toString(), 'android/app/build.gradle.kts:3');
        expect(all(fs, 'GD006'), isEmpty);
      },
    );

    test('GD005 says AGP 9 unsupported on Flutter < 3.44', () async {
      final fs = await findingsFor('agp9_kgp_applied', flutter: '3.41.0');
      final f = one(fs, 'GD005');
      expect(f.autoFixable, isFalse);
      expect(f.fix, contains('Stay on AGP 8.x'));
    });

    test(
      'GD006 warns with the legacy flag when the app still applies KGP',
      () async {
        final fs = await findingsFor('agp9_legacy_flag', flutter: '3.47.0');
        final f = one(fs, 'GD006');
        expect(f.severity, Severity.warning);
        expect(f.fix, contains('Migrate android/app/build.gradle'));
        expect(all(fs, 'GD005'), isEmpty);
      },
    );

    test('GD006 is info when nothing needs the legacy flag', () async {
      final s = await snapshotOf('healthy_347', flutter: '3.47.0');
      // Pretend the flag is false in an otherwise migrated project.
      final ctx = RuleContext(
        snapshot: ProjectSnapshot(
          projectDir: s.projectDir,
          hasAndroidDir: true,
          flutterVersion: s.flutterVersion,
          agpVersion: s.agpVersion,
          kgpApplied: const Detected(false),
          builtInKotlin: const Detected(
            false,
            source: SourceRef('android/gradle.properties', 4),
          ),
          plugins: const [],
          pluginsScanned: true,
        ),
        matrix: matrix,
      );
      final f = one(runRules(projectRules, ctx), 'GD006');
      expect(f.severity, Severity.info);
    });

    test('GD006 lists plugin blockers', () async {
      final fs = await findingsFor('with_plugins', flutter: '3.47.0');
      final f = one(fs, 'GD006');
      expect(f.severity, Severity.warning);
      expect(f.data['blockers'], ['kgp_plugin']);
    });

    test(
      'GD007 errors when builtInKotlin=true but a plugin applies KGP',
      () async {
        final s = await snapshotOf('with_plugins', flutter: '3.47.0');
        final ctx = RuleContext(
          snapshot: ProjectSnapshot(
            projectDir: s.projectDir,
            hasAndroidDir: true,
            flutterVersion: s.flutterVersion,
            agpVersion: s.agpVersion,
            kgpApplied: const Detected(false),
            builtInKotlin: const Detected(
              true,
              source: SourceRef('android/gradle.properties', 6),
            ),
            plugins: s.plugins,
            pluginsScanned: true,
          ),
          matrix: matrix,
        );
        final f = one(runRules(projectRules, ctx), 'GD007');
        expect(f.severity, Severity.error);
        expect(f.message, contains('kgp_plugin 1.0.0'));
      },
    );
  });

  group('GD008 imperative apply', () {
    test('reports both app and settings', () async {
      final fs = await findingsFor('old_groovy');
      final g8 = all(fs, 'GD008');
      expect(g8, hasLength(2));
      expect(
        g8.map((f) => f.source!.file),
        containsAll(['android/app/build.gradle', 'android/settings.gradle']),
      );
    });

    test('silent on declarative projects', () async {
      expect(all(await findingsFor('declarative_groovy'), 'GD008'), isEmpty);
    });
  });

  group('GD009 namespace', () {
    test('warning on AGP 7, error on AGP 8+', () async {
      final f = one(await findingsFor('old_groovy'), 'GD009');
      expect(f.severity, Severity.warning);
      expect(f.autoFixable, isTrue);
      expect(f.data['manifest_package'], 'com.example.old_groovy');
    });
  });

  group('GD010 JVM target mismatch', () {
    test('kotlin_dsl mixes Java 17 and jvmTarget 11', () async {
      final g10 = all(await findingsFor('kotlin_dsl'), 'GD010');
      expect(g10, hasLength(2));
    });

    test('jvmToolchain silences it', () async {
      expect(all(await findingsFor('version_catalog'), 'GD010'), isEmpty);
    });
  });

  group('GD011 / GD012 SDK levels', () {
    test('hard-coded levels are info, low minSdk is a warning', () async {
      final fs = await findingsFor('old_groovy', flutter: '3.47.0');
      expect(
        all(fs, 'GD011').map((f) => f.data['name']),
        containsAll(['compileSdk', 'targetSdk', 'minSdk']),
      );
      final g12 = one(fs, 'GD012');
      expect(g12.severity, Severity.warning);
      expect(g12.data['default'], 24);
    });

    test('flutter.* variables produce nothing', () async {
      final fs = await findingsFor('healthy_347', flutter: '3.47.0');
      expect(all(fs, 'GD011'), isEmpty);
    });
  });

  group('GD013 jcenter', () {
    test('one finding per occurrence', () async {
      final g13 = all(await findingsFor('old_groovy'), 'GD013');
      expect(g13.map((f) => f.source!.line), [6, 19]);
      expect(g13.every((f) => f.autoFixable), isTrue);
    });
  });

  group('GD014 old template', () {
    test('fires when created far in the past', () async {
      var s = await snapshotOf('old_groovy', flutter: '3.47.0');
      s = s.copyWith(
        createdWithFlutter: const Detected(
          '3.10.0',
          source: SourceRef('.metadata', 7),
        ),
      );
      final f = one(
        runRules(projectRules, RuleContext(snapshot: s, matrix: matrix)),
        'GD014',
      );
      expect(f.severity, Severity.info);
    });

    test('silent for recent projects', () async {
      var s = await snapshotOf('healthy_347', flutter: '3.47.0');
      s = s.copyWith(createdWithFlutter: const Detected('3.44.0'));
      expect(
        all(
          runRules(projectRules, RuleContext(snapshot: s, matrix: matrix)),
          'GD014',
        ),
        isEmpty,
      );
    });
  });

  group('GD015 CI Java', () {
    test('mismatch with local Java', () async {
      final f = one(await findingsFor('declarative_groovy', java: 17), 'GD015');
      expect(f.data['ci_java'], 21);
    });

    test('matching is silent', () async {
      expect(
        all(await findingsFor('declarative_groovy', java: 21), 'GD015'),
        isEmpty,
      );
    });
  });

  group('plugin rules', () {
    test('GP001..GP004 on the fixture plugins', () async {
      final fs = await findingsFor(
        'with_plugins',
        flutter: '3.47.0',
        rules: pluginRules,
      );
      final gp1 = one(fs, 'GP001');
      expect(gp1.severity, Severity.warning); // builtInKotlin=false
      expect(gp1.data['plugin'], 'kgp_plugin');
      expect(one(fs, 'GP002').data['plugin'], 'no_namespace_plugin');
      expect(one(fs, 'GP003').data['plugin'], 'no_namespace_plugin');
      final gp4 = all(fs, 'GP004');
      expect(
        gp4.map((f) => f.data['plugin']),
        containsAll(['kgp_plugin', 'no_namespace_plugin']),
      );
      expect(gp4.any((f) => f.data['kgp'] == '1.8.22'), isTrue);
      expect(all(fs, 'GP005'), isEmpty);
    });

    test('GP001 is an error with builtInKotlin=true', () async {
      final s = await snapshotOf('with_plugins', flutter: '3.47.0');
      final ctx = RuleContext(
        snapshot: ProjectSnapshot(
          projectDir: s.projectDir,
          hasAndroidDir: true,
          agpVersion: s.agpVersion,
          builtInKotlin: const Detected(true),
          plugins: s.plugins,
          pluginsScanned: true,
        ),
        matrix: matrix,
      );
      expect(one(runRules(pluginRules, ctx), 'GP001').severity, Severity.error);
    });

    test('GP005 uses pub.dev latest versions', () async {
      final s = await snapshotOf('with_plugins', flutter: '3.47.0');
      final withLatest = s.withPlugins([
        for (final p in s.plugins)
          p.withLatestVersion(p.name == 'kgp_plugin' ? '2.0.0' : p.version),
      ]);
      final fs = runRules(
        pluginRules,
        RuleContext(snapshot: withLatest, matrix: matrix),
      );
      final gp5 = one(fs, 'GP005');
      expect(gp5.data['plugin'], 'kgp_plugin');
      expect(one(fs, 'GP001').fix, contains('1.0.0 -> 2.0.0'));
    });
  });

  test('runRules honours ignore and sorts by severity', () async {
    final s = await snapshotOf('old_groovy', flutter: '3.47.0');
    final fs = runRules(
      projectRules,
      RuleContext(snapshot: s, matrix: matrix),
      ignore: {'GD011'},
    );
    expect(ids(fs), isNot(contains('GD011')));
    final ranks = fs.map((f) => f.severity.rank).toList();
    expect(ranks, orderedEquals(ranks.toList()..sort()));
  });
}
