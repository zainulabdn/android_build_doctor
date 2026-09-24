import '../util/text_file.dart';

/// Regular expressions shared by the Gradle-file detectors. Each pattern
/// works for both Groovy (`id "x" version "y"`) and Kotlin DSL
/// (`id("x") version "y"`) spellings.
class GradlePatterns {
  GradlePatterns._();

  /// `id "com.android.application" version "8.1.0"` (Groovy or KTS).
  static final RegExp agpPluginVersion = RegExp(
    r'''id\s*\(?\s*["']com\.android\.(?:application|library)["']\s*\)?\s*(?:\.\s*)?version\s*\(?\s*["']([^"']+)["']''',
  );

  /// `id "org.jetbrains.kotlin.android" version "1.8.22"` or
  /// `kotlin("android") version "1.8.22"`.
  static final RegExp kgpPluginVersion = RegExp(
    r'''(?:id\s*\(?\s*["']org\.jetbrains\.kotlin\.android["']\s*\)?|kotlin\s*\(\s*["']android["']\s*\))\s*(?:\.\s*)?version\s*\(?\s*["']([^"']+)["']''',
  );

  /// `classpath 'com.android.tools.build:gradle:7.3.0'` (any quoting).
  static final RegExp agpClasspath = RegExp(
    r'''classpath\s*\(?\s*["']com\.android\.tools\.build:gradle:([^"']+)["']''',
  );

  /// `classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"`.
  static final RegExp kgpClasspath = RegExp(
    r'''classpath\s*\(?\s*["']org\.jetbrains\.kotlin:kotlin-gradle-plugin:([^"']+)["']''',
  );

  /// `alias(libs.plugins.android.application)`.
  static final RegExp aliasPlugin = RegExp(
    r'alias\s*\(\s*libs\.plugins\.([A-Za-z0-9_.]+)\s*\)',
  );

  /// Lines that *apply* KGP to a module. Lines with `apply false` are
  /// skipped by the caller.
  static final RegExp kgpApply = RegExp(
    r'''(?:id\s*\(?\s*["'](?:kotlin-android|org\.jetbrains\.kotlin\.android)["']\s*\)?|apply\s+plugin:\s*["'](?:kotlin-android|org\.jetbrains\.kotlin\.android)["']|kotlin\s*\(\s*["']android["']\s*\)|alias\s*\(\s*libs\.plugins\.kotlin[.-]android\s*\))''',
  );

  /// `id "dev.flutter.flutter-gradle-plugin"`.
  static final RegExp flutterPluginDeclarative = RegExp(
    r'''id\s*\(?\s*["']dev\.flutter\.flutter-gradle-plugin["']''',
  );

  /// `apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"`.
  static final RegExp flutterPluginImperative = RegExp(
    r'''apply\s+from:\s*["'][^"']*flutter\.gradle["']''',
  );

  /// `namespace = "com.example.app"` or `namespace "com.example.app"`.
  static final RegExp namespace = RegExp(
    r'''^\s*namespace\s*=?\s*["']([^"']+)["']''',
  );

  /// `compileSdk = 34`, `compileSdkVersion 33`, `compileSdk flutter.compileSdkVersion`,
  /// `compileSdk = maxOf(flutter.compileSdkVersion, 35)`. The whole expression is
  /// captured; [cleanExpression] trims comments and stray separators.
  static final RegExp compileSdk = RegExp(
    r'^\s*compileSdk(?:Version)?\s*=?\s*(\S.*?)\s*$',
  );

  /// `minSdk = 21` / `minSdkVersion flutter.minSdkVersion` /
  /// `minSdk = maxOf(flutter.minSdkVersion, 23)`.
  static final RegExp minSdk = RegExp(
    r'^\s*minSdk(?:Version)?\s*=?\s*(\S.*?)\s*$',
  );

  /// `targetSdk = 34` / `targetSdkVersion 33`.
  static final RegExp targetSdk = RegExp(
    r'^\s*targetSdk(?:Version)?\s*=?\s*(\S.*?)\s*$',
  );

  /// `sourceCompatibility = JavaVersion.VERSION_17` / `sourceCompatibility 1.8`.
  static final RegExp sourceCompatibility = RegExp(
    r'^\s*sourceCompatibility\s*=?\s*([^\s/]+)',
  );

  /// `targetCompatibility = JavaVersion.VERSION_17`.
  static final RegExp targetCompatibility = RegExp(
    r'^\s*targetCompatibility\s*=?\s*([^\s/]+)',
  );

  /// `jvmTarget = '1.8'` / `jvmTarget = JavaVersion.VERSION_17.toString()` /
  /// `jvmTarget = JvmTarget.JVM_17`.
  static final RegExp jvmTarget = RegExp(r'^\s*jvmTarget\s*=?\s*(.+?)\s*$');

  /// `jvmToolchain(17)`.
  static final RegExp jvmToolchain = RegExp(r'jvmToolchain\s*\(\s*(\d+)\s*\)');

  /// `compilerOptions {` (new Kotlin DSL block).
  static final RegExp compilerOptions = RegExp(r'^\s*compilerOptions\s*\{');

  /// `kotlinOptions {` (legacy block).
  static final RegExp kotlinOptions = RegExp(r'^\s*kotlinOptions\s*\{');

  /// `jcenter()`.
  static final RegExp jcenter = RegExp(r'\bjcenter\s*\(\s*\)');

  /// `ext.kotlin_version = '1.7.10'`, `kotlin_version = '1.7.10'`,
  /// `val kotlinVersion = "1.8.22"`, `def agpVersion = "8.1.0"`,
  /// `extra["kotlin_version"] = "1.8.22"`.
  static RegExp variableDefinition(String name) {
    final n = RegExp.escape(name);
    final alternatives = [
      r'ext\.' + n,
      r'(?<![$\w.])' + n,
      r'''extra\s*\[\s*["']''' + n + r'''["']\s*\]''',
      r'''set\s*\(\s*["']''' + n + r'''["']\s*,''',
    ].join('|');
    return RegExp(
      '(?:$alternatives)'
      r'''\s*=?\s*["']([^"']+)["']''',
    );
  }

  /// A `$name`, `${name}`, `"${name}"` reference or a bare identifier.
  static final RegExp variableReference = RegExp(
    r'^\$\{?([A-Za-z_][A-Za-z0-9_.]*)\}?$|^([A-Za-z_][A-Za-z0-9_]*)$',
  );

  /// `distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-all.zip`.
  static final RegExp distributionUrl = RegExp(
    r'^\s*distributionUrl\s*=\s*.*gradle-([0-9][0-9A-Za-z.\-]*?)-(?:all|bin)\.zip',
  );

  /// `package="com.example.app"` in AndroidManifest.xml.
  static final RegExp manifestPackage = RegExp(
    r'''\bpackage\s*=\s*["']([^"']+)["']''',
  );

  /// `java-version: '17'` in GitHub Actions workflows.
  static final RegExp ciJavaVersion = RegExp(r'''java-version:\s*["']?(\d+)''');

  /// Cleans a captured Gradle expression: drops a trailing `//` line comment
  /// and trailing separators, while keeping balanced parentheses intact so
  /// that `maxOf(flutter.minSdkVersion, 23)` survives whole.
  static String cleanExpression(String raw) {
    var e = raw.split('//').first.trim();
    while (e.isNotEmpty) {
      final last = e[e.length - 1];
      if (last == ',' || last == ';') {
        e = e.substring(0, e.length - 1).trimRight();
        continue;
      }
      if (last == ')' && ')'.allMatches(e).length > '('.allMatches(e).length) {
        e = e.substring(0, e.length - 1).trimRight();
        continue;
      }
      break;
    }
    return e;
  }

  /// Resolves `raw` when it is a `$variable` / `${variable}` reference or a
  /// bare identifier, using definitions found in `files`. Literals and
  /// unresolvable references are returned unchanged (with `null` line).
  static ({String value, int? line, TextFile? file}) resolveVariable(
    String raw,
    List<TextFile> files,
  ) {
    if (RegExp(r'^\d').hasMatch(raw)) {
      return (value: raw, line: null, file: null);
    }
    final ref = variableReference.firstMatch(raw);
    final name = ref?.group(1) ?? ref?.group(2);
    if (name == null) return (value: raw, line: null, file: null);
    final shortName = name.split('.').last;
    for (final f in files) {
      final def = f.firstMatch(variableDefinition(shortName));
      if (def != null) return (value: def.group(1)!, line: def.line, file: f);
    }
    return (value: raw, line: null, file: null);
  }
}
