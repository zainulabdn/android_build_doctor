import 'package:path/path.dart' as p;

import '../model/source_ref.dart';
import '../util/text_file.dart';

/// Reads flags from `android/gradle.properties`.
class GradlePropertiesDetector {
  /// Loads `android/gradle.properties` if present.
  GradlePropertiesDetector(String androidDir, {String? projectDir})
    : file = TextFile.read(
        p.join(androidDir, 'gradle.properties'),
        relativeTo: projectDir ?? p.dirname(androidDir),
      );

  /// The properties file, or `null` when missing.
  final TextFile? file;

  /// Whether the file exists.
  bool get exists => file != null;

  /// Reads a raw property value (last occurrence wins, like Gradle).
  Detected<String>? property(String name) {
    final f = file;
    if (f == null) return null;
    final re = RegExp('^\\s*${RegExp.escape(name)}\\s*[=:]\\s*(.*?)\\s*\$');
    final matches = f.allMatches(re);
    if (matches.isEmpty) return null;
    final m = matches.last;
    return Detected(m.group(1)!, source: m.ref, raw: m.text.trim());
  }

  /// Reads a boolean property (`true`/`false`, case-insensitive).
  Detected<bool>? boolProperty(String name) {
    final v = property(name);
    if (v == null) return null;
    final b = v.value.toLowerCase() == 'true';
    return Detected(b, source: v.source, raw: v.raw);
  }

  /// `android.builtInKotlin`.
  Detected<bool>? get builtInKotlin => boolProperty('android.builtInKotlin');

  /// `android.newDsl`.
  Detected<bool>? get newDsl => boolProperty('android.newDsl');

  /// `org.gradle.java.home`.
  Detected<String>? get javaHome => property('org.gradle.java.home');
}
