import 'package:pub_semver/pub_semver.dart';

/// Helpers for the loose version strings found in Gradle land.
///
/// Gradle writes `8.12`, AGP writes `8.7.3`, Kotlin writes `2.1.0-RC2`, Java
/// writes `17.0.12` or `1.8.0_392`. Everything is normalised to a
/// [Version] so comparisons use `pub_semver` rather than hand-rolled logic.
class Versions {
  Versions._();

  static final RegExp _lead = RegExp(r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?(.*)$');

  /// Parses `text` leniently. Returns `null` when it does not start with a
  /// number.
  static Version? parse(String? text) {
    if (text == null) return null;
    final t = text.trim();
    final m = _lead.firstMatch(t);
    if (m == null) return null;
    final major = int.parse(m.group(1)!);
    final minor = int.tryParse(m.group(2) ?? '') ?? 0;
    final patch = int.tryParse(m.group(3) ?? '') ?? 0;
    var rest = m.group(4) ?? '';
    // Gradle uses "-rc-1" / "-milestone-2"; Kotlin uses "-RC2" / "-Beta1".
    String? pre;
    if (rest.isNotEmpty) {
      rest = rest.replaceFirst(RegExp(r'^[-._]'), '');
      pre = rest
          .replaceAll(RegExp(r'[^0-9A-Za-z.-]'), '')
          .replaceAll(RegExp(r'-+'), '.')
          .replaceAll(RegExp(r'\.+'), '.')
          .replaceAll(RegExp(r'^\.|\.$'), '');
      if (pre.isEmpty) pre = null;
    }
    try {
      return Version(major, minor, patch, pre: pre);
    } on FormatException {
      return Version(major, minor, patch);
    }
  }

  /// Compares two loose versions. Unparseable values sort first.
  static int compare(String a, String b) {
    final va = parse(a);
    final vb = parse(b);
    if (va == null && vb == null) return 0;
    if (va == null) return -1;
    if (vb == null) return 1;
    return va.compareTo(vb);
  }

  /// True when `actual` is strictly lower than `minimum`.
  static bool isBelow(String actual, String minimum) =>
      compare(actual, minimum) < 0;

  /// True when `actual` is greater than or equal to `minimum`.
  static bool atLeast(String actual, String minimum) =>
      compare(actual, minimum) >= 0;

  /// `major.minor` of a version string, for example `3.47.1` to `3.47`.
  static String majorMinor(String text) {
    final v = parse(text);
    if (v == null) return text;
    return '${v.major}.${v.minor}';
  }

  /// True when `text` is within the `major.minor` series of `series`.
  static bool inSeries(String text, String series) {
    final v = parse(text);
    final s = parse(series);
    if (v == null || s == null) return false;
    if (series.split('.').length == 1) return v.major == s.major;
    return v.major == s.major && v.minor == s.minor;
  }

  static final RegExp _javaVersionLine = RegExp(r'version\s+"([^"]+)"');
  static final RegExp _javaEnum = RegExp(r'VERSION_(\d+)(?:_(\d+))?');
  static final RegExp _jvmEnum = RegExp(r'JVM_(\d+)(?:_(\d+))?');

  /// Extracts a Java *major* version from many spellings:
  /// `17`, `1.8`, `17.0.12`, `1.8.0_392`, `JavaVersion.VERSION_1_8`,
  /// `JavaVersion.VERSION_17`, `JvmTarget.JVM_17`, `JvmTarget.JVM_1_8`, or the
  /// first line of `java -version` output.
  static int? javaMajor(String? text) {
    if (text == null) return null;
    var t = text.trim();
    final line = _javaVersionLine.firstMatch(t);
    if (line != null) t = line.group(1)!;
    final e = _javaEnum.firstMatch(t) ?? _jvmEnum.firstMatch(t);
    if (e != null) {
      final a = int.parse(e.group(1)!);
      final b = e.group(2);
      return a == 1 && b != null ? int.parse(b) : a;
    }
    t = t.replaceAll(RegExp('''^["']|["']\$'''), '');
    final m = RegExp(r'^(\d+)(?:\.(\d+))?').firstMatch(t);
    if (m == null) return null;
    final a = int.parse(m.group(1)!);
    final b = m.group(2);
    if (a == 1 && b != null) return int.parse(b);
    return a;
  }

  /// Java version for a class-file major number (52 = Java 8, 61 = Java 17).
  static int javaFromClassFileMajor(int major) => major - 44;
}
