import 'package:path/path.dart' as p;

import '../model/source_ref.dart';
import 'gradle_patterns.dart';
import '../util/text_file.dart';

/// Reads the Gradle version from `android/gradle/wrapper/gradle-wrapper.properties`.
class WrapperDetector {
  WrapperDetector._();

  /// Relative path of the wrapper properties file inside `android/`.
  static const String relativePath = 'gradle/wrapper/gradle-wrapper.properties';

  /// Returns the Gradle version with its file and line, or `null`.
  static Detected<String>? detect(String androidDir, {String? projectDir}) {
    final file = TextFile.read(
      p.join(androidDir, relativePath),
      relativeTo: projectDir ?? p.dirname(androidDir),
    );
    if (file == null) return null;
    final m = file.firstMatch(GradlePatterns.distributionUrl);
    if (m == null) return null;
    return Detected(m.group(1)!, source: m.ref, raw: m.text.trim());
  }
}
