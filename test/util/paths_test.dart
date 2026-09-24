import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('path normalisation', () {
    test('converts Windows separators for display', () {
      expect(
        toPosixPath(r'android\app\build.gradle.kts', windows: true),
        'android/app/build.gradle.kts',
      );
      expect(
        toPosixPath(r'C:\proj\android\gradle.properties', windows: true),
        'C:/proj/android/gradle.properties',
      );
    });

    test('leaves POSIX paths alone', () {
      expect(
        toPosixPath('android/app/build.gradle', windows: false),
        'android/app/build.gradle',
      );
      // A backslash is a legal filename character on POSIX, so it must survive.
      expect(
        toPosixPath(r'weird\name.gradle', windows: false),
        r'weird\name.gradle',
      );
    });

    test('round trips back to native', () {
      const posix = 'android/gradle/wrapper/gradle-wrapper.properties';
      expect(
        toNativePath(posix, windows: true),
        r'android\gradle\wrapper\gradle-wrapper.properties',
      );
      expect(
        toPosixPath(toNativePath(posix, windows: true), windows: true),
        posix,
      );
      expect(toNativePath(posix, windows: false), posix);
    });
  });

  test('no finding or detected value reports a backslash separator', () async {
    for (final name in [
      'old_groovy',
      'declarative_groovy',
      'kotlin_dsl',
      'version_catalog',
      'with_plugins',
    ]) {
      final s = await snapshotOf(name, flutter: '3.47.0', java: 17);
      final ctx = RuleContext(snapshot: s, matrix: matrix);
      for (final f in runRules([...projectRules, ...pluginRules], ctx)) {
        expect(
          f.source?.file ?? '',
          isNot(contains(r'\')),
          reason: '${f.id} in $name must report a forward-slash path',
        );
      }
      for (final d in [
        s.gradleVersion?.source,
        s.agpVersion?.source,
        s.kgpVersion?.source,
        s.builtInKotlin?.source,
        s.namespace?.source,
      ]) {
        expect(d?.file ?? '', isNot(contains(r'\')), reason: name);
      }
    }
  });
}
