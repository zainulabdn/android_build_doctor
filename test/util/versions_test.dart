import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:test/test.dart';

void main() {
  test('parses loose versions', () {
    expect(Versions.parse('8.12').toString(), '8.12.0');
    expect(Versions.parse('9.3.1').toString(), '9.3.1');
    expect(Versions.parse('17').toString(), '17.0.0');
    expect(Versions.parse('2.1.0-RC2')!.isPreRelease, isTrue);
    expect(Versions.parse('9.0.0-rc-1')!.isPreRelease, isTrue);
    expect(Versions.parse(r'$kotlin_version'), isNull);
    expect(Versions.parse('abc'), isNull);
  });

  test('compares', () {
    expect(Versions.isBelow('8.7', '9.3.1'), isTrue);
    expect(Versions.isBelow('8.14', '8.14.0'), isFalse);
    expect(Versions.atLeast('8.14', '8.13'), isTrue);
    expect(Versions.compare('9.1.0-rc-1', '9.1.0') < 0, isTrue);
  });

  test('majorMinor and inSeries', () {
    expect(Versions.majorMinor('3.47.1'), '3.47');
    expect(Versions.inSeries('9.1.3', '9.1'), isTrue);
    expect(Versions.inSeries('9.2.0', '9.1'), isFalse);
  });

  test('javaMajor understands every spelling', () {
    expect(Versions.javaMajor('17'), 17);
    expect(Versions.javaMajor('1.8'), 8);
    expect(Versions.javaMajor("'1.8'"), 8);
    expect(Versions.javaMajor('"21"'), 21);
    expect(Versions.javaMajor('JavaVersion.VERSION_1_8'), 8);
    expect(Versions.javaMajor('JavaVersion.VERSION_17'), 17);
    expect(Versions.javaMajor('JavaVersion.VERSION_17.toString()'), 17);
    expect(Versions.javaMajor('JvmTarget.JVM_17'), 17);
    expect(
      Versions.javaMajor('org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8'),
      8,
    );
    expect(Versions.javaMajor('openjdk version "17.0.12" 2024-07-16'), 17);
    expect(Versions.javaMajor('java version "1.8.0_392"'), 8);
    expect(Versions.javaMajor('openjdk version "21" 2023-09-19 LTS'), 21);
    expect(Versions.javaMajor('nonsense'), isNull);
  });

  test('class file major to java', () {
    expect(Versions.javaFromClassFileMajor(65), 21);
    expect(Versions.javaFromClassFileMajor(61), 17);
  });
}
