import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/source_ref.dart';
import '../util/process.dart';

/// What was learned about the Flutter SDK in use.
class FlutterInfo {
  /// Creates the info.
  const FlutterInfo({
    this.flutterVersion,
    this.source,
    this.dartVersion,
    this.flutterRoot,
    this.executable,
    this.notes = const [],
  });

  /// Flutter framework version.
  final Detected<String>? flutterVersion;

  /// Human description of where the version came from.
  final String? source;

  /// Dart SDK version.
  final Detected<String>? dartVersion;

  /// Flutter SDK root directory.
  final String? flutterRoot;

  /// The `flutter` executable that was (or would be) run.
  final String? executable;

  /// Detection notes.
  final List<String> notes;
}

/// Detects the Flutter version: FVM config, then `flutter --version --machine`.
class FlutterDetector {
  FlutterDetector._();

  /// Name of the flutter executable on this platform.
  static String get flutterExecutable =>
      Platform.isWindows ? 'flutter.bat' : 'flutter';

  /// The FVM-pinned version for `projectDir`, if any.
  static Detected<String>? fvmVersion(String projectDir) {
    for (final (name, key) in [
      ('.fvmrc', 'flutter'),
      (p.join('.fvm', 'fvm_config.json'), 'flutterSdkVersion'),
    ]) {
      final f = File(p.join(projectDir, name));
      if (!f.existsSync()) continue;
      try {
        final doc = jsonDecode(f.readAsStringSync());
        if (doc is Map && doc[key] is String) {
          return Detected(doc[key] as String, source: SourceRef(name));
        }
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  /// Detects the Flutter SDK for `projectDir`.
  static Future<FlutterInfo> detect(
    String projectDir, {
    RunProcess run = defaultRunProcess,
  }) async {
    final notes = <String>[];
    final fvm = fvmVersion(projectDir);
    var exe = flutterExecutable;
    var source = 'flutter --version';
    final fvmSdk = p.join(
      projectDir,
      '.fvm',
      'flutter_sdk',
      'bin',
      flutterExecutable,
    );
    if (fvm != null && File(fvmSdk).existsSync()) {
      exe = fvmSdk;
      source = 'FVM (${fvm.source})';
    }

    final result = await run(exe, [
      '--version',
      '--machine',
    ], workingDirectory: projectDir);
    if (result != null && result.exitCode == 0) {
      final out = result.stdout.toString();
      final start = out.indexOf('{');
      if (start >= 0) {
        try {
          final json = jsonDecode(out.substring(start));
          if (json is Map) {
            final fv = (json['frameworkVersion'] ?? json['flutterVersion'])
                ?.toString();
            final dv = json['dartSdkVersion']?.toString();
            return FlutterInfo(
              flutterVersion: fv == null ? null : Detected(fv),
              source: source,
              dartVersion: dv == null ? null : Detected(dv.split(' ').first),
              flutterRoot: json['flutterRoot']?.toString(),
              executable: exe,
              notes: notes,
            );
          }
        } on FormatException {
          notes.add('could not parse `flutter --version --machine` output');
        }
      }
    } else {
      notes.add(
        result == null
            ? '`$exe` not found on PATH; Flutter version taken from config files only'
            : '`flutter --version` failed (exit ${result.exitCode})',
      );
    }

    if (fvm != null) {
      return FlutterInfo(
        flutterVersion: fvm,
        source: 'FVM config (${fvm.source})',
        executable: exe,
        notes: notes,
      );
    }
    return FlutterInfo(executable: exe, notes: notes);
  }

  /// Resolves a Flutter git revision (from `.metadata`) to a version tag using
  /// the SDK checkout at `flutterRoot`. Returns `null` when git cannot tell.
  static Future<String?> versionForRevision(
    String revision,
    String? flutterRoot, {
    RunProcess run = defaultRunProcess,
  }) async {
    if (flutterRoot == null) return null;
    final r = await run('git', [
      '-C',
      flutterRoot,
      'describe',
      '--tags',
      '--abbrev=0',
      revision,
    ]);
    if (r == null || r.exitCode != 0) return null;
    final tag = r.stdout.toString().trim();
    if (!RegExp(r'^\d+\.\d+').hasMatch(tag)) return null;
    return tag;
  }
}
