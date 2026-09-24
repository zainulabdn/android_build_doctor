import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('WrapperDetector', () {
    test('reads the Gradle version with file and line', () {
      final v = WrapperDetector.detect(
        p.join(project('old_groovy'), 'android'),
        projectDir: project('old_groovy'),
      );
      expect(v!.value, '7.5');
      expect(
        v.source!.file,
        'android/gradle/wrapper/gradle-wrapper.properties',
      );
      expect(v.source!.line, 5);
    });

    test('handles -bin distributions and rc versions', () {
      final f = TextFile(
        'x',
        'distributionUrl=https\\://services.gradle.org/distributions/gradle-9.0.0-rc-1-bin.zip',
      );
      final m = f.firstMatch(GradlePatterns.distributionUrl);
      expect(m!.group(1), '9.0.0-rc-1');
    });
  });

  group('GradleVersionsDetector', () {
    test('legacy buildscript classpath with ext.kotlin_version', () {
      final v = GradleVersionsDetector.detect(
        p.join(project('old_groovy'), 'android'),
        projectDir: project('old_groovy'),
      );
      expect(v.agp!.value, '7.3.0');
      expect(v.agp!.source.toString(), 'android/build.gradle:10');
      expect(v.kgp!.value, '1.7.10');
      expect(v.kgp!.source.toString(), 'android/build.gradle:2');
      expect(v.style, GradleDeclarationStyle.buildscriptClasspath);
      expect(v.jcenterRefs.map((r) => r.line), [6, 19]);
      expect(v.legacyPluginLoaderRef.toString(), 'android/settings.gradle:11');
    });

    test('declarative Groovy plugins block', () {
      final v = GradleVersionsDetector.detect(
        p.join(project('declarative_groovy'), 'android'),
        projectDir: project('declarative_groovy'),
      );
      expect(v.agp!.value, '8.1.0');
      expect(v.agp!.source.toString(), 'android/settings.gradle:21');
      expect(v.kgp!.value, '1.8.22');
      expect(v.style, GradleDeclarationStyle.pluginsBlock);
      expect(v.jcenterRefs, isEmpty);
      expect(v.legacyPluginLoaderRef, isNull);
    });

    test('Kotlin DSL plugins block', () {
      final v = GradleVersionsDetector.detect(
        p.join(project('kotlin_dsl'), 'android'),
        projectDir: project('kotlin_dsl'),
      );
      expect(v.agp!.value, '8.7.3');
      expect(v.agp!.source.toString(), 'android/settings.gradle.kts:21');
      expect(v.kgp!.value, '2.1.0');
      expect(v.style, GradleDeclarationStyle.pluginsBlock);
    });

    test('version catalog', () {
      final v = GradleVersionsDetector.detect(
        p.join(project('version_catalog'), 'android'),
        projectDir: project('version_catalog'),
      );
      expect(v.agp!.value, '8.9.1');
      expect(v.agp!.source.toString(), 'android/gradle/libs.versions.toml:2');
      expect(v.kgp!.value, '2.1.0');
      expect(v.kgp!.source.toString(), 'android/gradle/libs.versions.toml:3');
      expect(v.style, GradleDeclarationStyle.versionCatalog);
    });

    test('resolves \$variable references in kts', () {
      final f = TextFile('build.gradle.kts', '''
buildscript {
    val kotlinVersion = "1.9.10"
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:\$kotlinVersion")
    }
}
''');
      final m = f.firstMatch(GradlePatterns.kgpClasspath);
      expect(m!.group(1), r'$kotlinVersion');
      final def = f.firstMatch(
        GradlePatterns.variableDefinition('kotlinVersion'),
      );
      expect(def!.group(1), '1.9.10');
      expect(def.line, 2);
    });
  });

  group('AppGradleDetector', () {
    test('old Groovy app module', () {
      final info = AppGradleDetector.detect(
        p.join(project('old_groovy'), 'android', 'app'),
        relativeTo: project('old_groovy'),
      );
      expect(info.kgpApplied!.value, isTrue);
      expect(info.kgpApplied!.source.toString(), 'android/app/build.gradle:25');
      expect(info.flutterPluginApply!.value, FlutterPluginApply.imperative);
      expect(info.namespace, isNull);
      expect(info.compileSdk!.value.value, 33);
      expect(info.compileSdk!.value.usesFlutterVariable, isFalse);
      expect(info.minSdk!.value.value, 19);
      expect(info.targetSdk!.value.value, 33);
      expect(info.sourceCompatibility!.value, 8);
      expect(info.jvmTarget!.value, 8);
      expect(info.usesKotlinOptions, isTrue);
      expect(info.usesKotlinCompilerOptions, isFalse);
    });

    test('Kotlin DSL app module', () {
      final info = AppGradleDetector.detect(
        p.join(project('kotlin_dsl'), 'android', 'app'),
        relativeTo: project('kotlin_dsl'),
      );
      expect(info.kgpApplied!.value, isTrue);
      expect(info.flutterPluginApply!.value, FlutterPluginApply.declarative);
      expect(info.namespace!.value, 'com.example.kotlin_dsl');
      expect(info.compileSdk!.value.expression, 'flutter.compileSdkVersion');
      expect(info.compileSdk!.value.usesFlutterVariable, isTrue);
      expect(info.sourceCompatibility!.value, 17);
      expect(info.jvmTarget!.value, 11);
    });

    test('version catalog app module with alias() and jvmToolchain', () {
      final info = AppGradleDetector.detect(
        p.join(project('version_catalog'), 'android', 'app'),
        relativeTo: project('version_catalog'),
      );
      expect(info.kgpApplied!.value, isTrue);
      expect(info.kgpApplied!.raw, 'alias(libs.plugins.kotlin.android)');
      expect(info.jvmToolchain!.value, 17);
      expect(info.compileSdk!.value.value, 35);
      expect(info.minSdk!.value.value, 23);
    });

    test('captures whole SDK expressions, not just the first token', () {
      final f = TextFile('build.gradle.kts', '''
android {
    compileSdk = maxOf(flutter.compileSdkVersion, 35)
    defaultConfig {
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = 36 // pinned on purpose
    }
}
''');
      final info = AppGradleDetector.parse(f);
      expect(
        info.compileSdk!.value.expression,
        'maxOf(flutter.compileSdkVersion, 35)',
      );
      expect(info.compileSdk!.value.usesFlutterVariable, isTrue);
      expect(info.compileSdk!.value.isLiteral, isFalse);
      expect(info.minSdk!.value.expression, 'maxOf(flutter.minSdkVersion, 23)');
      expect(info.minSdk!.value.usesFlutterVariable, isTrue);
      expect(info.targetSdk!.value.expression, '36');
      expect(info.targetSdk!.value.value, 36);
    });

    test('cleanExpression trims comments and stray separators only', () {
      expect(GradlePatterns.cleanExpression('35 // comment'), '35');
      expect(
        GradlePatterns.cleanExpression('flutter.minSdkVersion,'),
        'flutter.minSdkVersion',
      );
      expect(
        GradlePatterns.cleanExpression('flutter.minSdkVersion)'),
        'flutter.minSdkVersion',
      );
      expect(GradlePatterns.cleanExpression('maxOf(a, 23)'), 'maxOf(a, 23)');
      expect(GradlePatterns.cleanExpression('maxOf(a, 23))'), 'maxOf(a, 23)');
    });

    test('migrated 3.47 app module', () {
      final info = AppGradleDetector.detect(
        p.join(project('healthy_347'), 'android', 'app'),
        relativeTo: project('healthy_347'),
      );
      expect(info.kgpApplied, isNull);
      expect(info.usesKotlinCompilerOptions, isTrue);
      expect(info.jvmTarget!.value, 17);
    });

    test('does not treat "apply false" as applying KGP', () {
      final f = TextFile(
        'settings.gradle.kts',
        'plugins {\n    id("org.jetbrains.kotlin.android") version "2.4.0" apply false\n}\n',
      );
      expect(AppGradleDetector.parse(f).kgpApplied, isNull);
    });

    test('ignores commented-out lines', () {
      final f = TextFile(
        'build.gradle',
        '// apply plugin: "kotlin-android"\nnamespace "x.y"\n',
      );
      final info = AppGradleDetector.parse(f);
      expect(info.kgpApplied, isNull);
      expect(info.namespace!.value, 'x.y');
    });
  });

  group('GradlePropertiesDetector', () {
    test('reads builtInKotlin and newDsl', () {
      final d = GradlePropertiesDetector(
        p.join(project('agp9_legacy_flag'), 'android'),
        projectDir: project('agp9_legacy_flag'),
      );
      expect(d.builtInKotlin!.value, isFalse);
      expect(d.builtInKotlin!.source.toString(), 'android/gradle.properties:6');
      expect(d.newDsl!.value, isFalse);
      expect(d.javaHome, isNull);
    });

    test('returns null when unset', () {
      final d = GradlePropertiesDetector(
        p.join(project('old_groovy'), 'android'),
        projectDir: project('old_groovy'),
      );
      expect(d.builtInKotlin, isNull);
    });
  });

  group('misc detectors', () {
    test('manifest package', () {
      final v = ManifestDetector.detect(
        p.join(project('old_groovy'), 'android'),
        projectDir: project('old_groovy'),
      );
      expect(v!.value, 'com.example.old_groovy');
      expect(v.source!.line, 2);
    });

    test('metadata android create_revision', () {
      final m = MetadataDetector.detect(project('old_groovy'));
      expect(m!.revision, '796c8ef79279f9c774545b9f9c1a2a2b0ec1d6a4');
      expect(m.channel, 'stable');
    });

    test('CI java-version', () {
      final ci = CiDetector.detect(project('declarative_groovy'));
      expect(ci.single.value, 21);
      expect(ci.single.source!.file, '.github/workflows/build.yml');
    });

    test('FVM config', () {
      expect(FlutterDetector.fvmVersion(project('old_groovy')), isNull);
    });
  });

  group('PluginsDetector', () {
    test('finds Android plugins through package_config.json', () {
      final r = PluginsDetector.detect(project('with_plugins'));
      expect(r.dartToolMissing, isFalse);
      expect(r.plugins.map((p) => p.name), [
        'clean_plugin',
        'kgp_plugin',
        'no_namespace_plugin',
      ]);
      final kgp = r.plugins.firstWhere((p) => p.name == 'kgp_plugin');
      expect(kgp.appliesKgp, isTrue);
      expect(kgp.version, '1.0.0');
      expect(kgp.namespace, 'com.example.kgp_plugin');
      expect(kgp.javaCompatibility, 8);
      expect(kgp.kgpClasspathVersion, '1.8.22');
      expect(kgp.isDirectDependency, isTrue);
      final ns = r.plugins.firstWhere((p) => p.name == 'no_namespace_plugin');
      expect(ns.missingNamespace, isTrue);
      expect(ns.jcenterRef, isNotNull);
      expect(ns.compileSdkLiteral, 30);
      final clean = r.plugins.firstWhere((p) => p.name == 'clean_plugin');
      expect(clean.appliesKgp, isFalse);
      expect(clean.missingNamespace, isFalse);
    });

    test('reports a missing .dart_tool', () {
      final r = PluginsDetector.detect(project('old_groovy'));
      expect(r.dartToolMissing, isTrue);
    });
  });

  group('ProjectDetector', () {
    test('assembles a snapshot without running commands', () async {
      final s = await snapshotOf('with_plugins');
      expect(s.hasAndroidDir, isTrue);
      expect(s.projectName, 'with_plugins');
      expect(s.agpVersion!.value, '9.1.0');
      expect(s.builtInKotlin!.value, isFalse);
      expect(s.plugins, hasLength(3));
      expect(s.kgpPlugins.single.name, 'kgp_plugin');
      expect(s.javaVersion, isNull);
      expect(s.flutterVersion, isNull);
    });
  });
}
