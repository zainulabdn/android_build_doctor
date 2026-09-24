import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/source_ref.dart';
import '../util/process.dart';
import '../util/versions.dart';

/// What was learned about the JDK that will run Gradle.
class JavaInfo {
  /// Creates the info.
  const JavaInfo({this.version, this.source, this.home, this.notes = const []});

  /// Java major version.
  final Detected<int>? version;

  /// Where the JDK was found.
  final String? source;

  /// JDK home directory (or the `java` binary when found on PATH).
  final String? home;

  /// Detection notes.
  final List<String> notes;
}

/// Finds the JDK the same way Flutter's tooling does:
///
/// 1. `org.gradle.java.home` in `android/gradle.properties` (Gradle itself
///    honours this before anything else),
/// 2. `flutter config --jdk-dir`,
/// 3. Android Studio's bundled JBR,
/// 4. `JAVA_HOME`,
/// 5. `java` on `PATH`.
class JavaDetector {
  JavaDetector._();

  /// Candidate Android Studio JDK locations for this platform.
  static List<String> androidStudioJdkCandidates(Map<String, String> env) {
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '';
    if (Platform.isMacOS) {
      return [
        '/Applications/Android Studio.app/Contents/jbr/Contents/Home',
        p.join(
          home,
          'Applications',
          'Android Studio.app',
          'Contents',
          'jbr',
          'Contents',
          'Home',
        ),
        '/Applications/Android Studio.app/Contents/jre/Contents/Home',
      ];
    }
    if (Platform.isWindows) {
      final pf = env['ProgramFiles'] ?? r'C:\Program Files';
      final local = env['LOCALAPPDATA'] ?? '';
      return [
        p.join(pf, 'Android', 'Android Studio', 'jbr'),
        p.join(pf, 'Android', 'Android Studio', 'jre'),
        p.join(local, 'Programs', 'Android Studio', 'jbr'),
      ];
    }
    return [
      '/opt/android-studio/jbr',
      p.join(home, 'android-studio', 'jbr'),
      '/usr/local/android-studio/jbr',
      '/snap/android-studio/current/android-studio/jbr',
      '/opt/android-studio/jre',
    ];
  }

  /// Detects the JDK.
  static Future<JavaInfo> detect({
    Detected<String>? gradleJavaHome,
    String flutterExecutable = 'flutter',
    RunProcess run = defaultRunProcess,
    Map<String, String>? environment,
  }) async {
    final env = environment ?? Platform.environment;
    final notes = <String>[];

    Future<JavaInfo?> probe(
      String home,
      String source, {
      SourceRef? ref,
    }) async {
      final bin = p.join(home, 'bin', Platform.isWindows ? 'java.exe' : 'java');
      if (!File(bin).existsSync()) {
        notes.add('$source points at $home but no java binary there');
        return null;
      }
      return _version(bin, source, home, run, ref: ref);
    }

    // 1. org.gradle.java.home
    if (gradleJavaHome != null) {
      final info = await probe(
        gradleJavaHome.value,
        'org.gradle.java.home (${gradleJavaHome.source})',
        ref: gradleJavaHome.source,
      );
      if (info != null) return info;
    }

    // 2. flutter config --jdk-dir
    final cfg = await run(flutterExecutable, ['config', '--list']);
    if (cfg != null && cfg.exitCode == 0) {
      final m = RegExp(
        r'^\s*jdk-dir:\s*(.+?)\s*$',
        multiLine: true,
      ).firstMatch(cfg.stdout.toString());
      final dir = m?.group(1);
      if (dir != null && dir.isNotEmpty && !dir.startsWith('(')) {
        final info = await probe(dir, 'flutter config --jdk-dir');
        if (info != null) return info;
      }
    }

    // 3. Android Studio bundled JDK
    for (final c in androidStudioJdkCandidates(env)) {
      if (Directory(c).existsSync()) {
        final info = await probe(c, 'Android Studio bundled JDK');
        if (info != null) return info;
      }
    }

    // 4. JAVA_HOME
    final javaHome = env['JAVA_HOME'];
    if (javaHome != null && javaHome.isNotEmpty) {
      final info = await probe(javaHome, 'JAVA_HOME');
      if (info != null) return info;
    }

    // 5. PATH
    final info = await _version('java', 'java on PATH', null, run);
    if (info != null) return info;
    notes.add(
      'no JDK found (tried gradle.properties, flutter config, '
      'Android Studio, JAVA_HOME, PATH)',
    );
    return JavaInfo(notes: notes);
  }

  static Future<JavaInfo?> _version(
    String bin,
    String source,
    String? home,
    RunProcess run, {
    SourceRef? ref,
  }) async {
    final r = await run(bin, ['-version']);
    if (r == null || r.exitCode != 0) return null;
    // `java -version` writes to stderr.
    final text = '${r.stderr}\n${r.stdout}';
    final line = text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.contains('version'), orElse: () => '');
    final major = Versions.javaMajor(line);
    if (major == null) return null;
    return JavaInfo(
      version: Detected(major, source: ref, raw: line),
      source: source,
      home: home ?? bin,
    );
  }
}
