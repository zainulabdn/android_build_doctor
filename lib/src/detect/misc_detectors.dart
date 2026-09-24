import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../model/source_ref.dart';
import '../util/text_file.dart';
import 'gradle_patterns.dart';

/// Reads `package="..."` from `android/app/src/main/AndroidManifest.xml`.
class ManifestDetector {
  ManifestDetector._();

  /// Returns the manifest `package`, or `null`.
  static Detected<String>? detect(String androidDir, {String? projectDir}) {
    final path = p.join(
      androidDir,
      'app',
      'src',
      'main',
      'AndroidManifest.xml',
    );
    final f = TextFile.read(
      path,
      relativeTo: projectDir ?? p.dirname(androidDir),
    );
    if (f == null) return null;
    for (var i = 0; i < f.lines.length; i++) {
      final line = f.lines[i];
      if (!line.contains('<manifest') &&
          !line.trimLeft().startsWith('package')) {
        continue;
      }
      final m = GradlePatterns.manifestPackage.firstMatch(line);
      if (m != null) return Detected(m.group(1)!, source: f.ref(i + 1));
    }
    // package= may be on its own line after <manifest.
    final m = f.firstMatch(GradlePatterns.manifestPackage);
    return m == null ? null : Detected(m.group(1)!, source: m.ref);
  }
}

/// Reads the Flutter revision the project was created with from `.metadata`.
class MetadataDetector {
  MetadataDetector._();

  /// Returns the create revision (android platform first, else the file's
  /// top-level revision) and channel, or `null` when unavailable.
  static ({String revision, String? channel, SourceRef ref})? detect(
    String projectDir,
  ) {
    final f = TextFile.read(
      p.join(projectDir, '.metadata'),
      relativeTo: projectDir,
    );
    if (f == null) return null;
    String? revision;
    String? channel;
    int line = 1;
    try {
      final doc = loadYaml(f.content);
      if (doc is Map) {
        final v = doc['version'];
        if (v is Map) {
          revision = v['revision']?.toString();
          channel = v['channel']?.toString();
        }
        final mig = doc['migration'];
        if (mig is Map && mig['platforms'] is List) {
          for (final pl in mig['platforms'] as List) {
            if (pl is Map && pl['platform'] == 'android') {
              revision = pl['create_revision']?.toString() ?? revision;
            }
          }
        }
      }
    } on Object {
      // fall through to regex
    }
    if (revision == null) {
      final m = f.firstMatch(RegExp(r'revision:\s*([0-9a-f]{7,40})'));
      if (m == null) return null;
      revision = m.group(1);
      line = m.line;
    } else {
      final m = f.firstMatch(RegExp(RegExp.escape(revision)));
      if (m != null) line = m.line;
    }
    return (revision: revision!, channel: channel, ref: f.ref(line));
  }
}

/// Reads `java-version:` from GitHub Actions workflows.
class CiDetector {
  CiDetector._();

  /// Every `java-version` found in `.github/workflows/*.yml|yaml`.
  static List<Detected<int>> detect(String projectDir) {
    final dir = Directory(p.join(projectDir, '.github', 'workflows'));
    if (!dir.existsSync()) return const [];
    final out = <Detected<int>>[];
    final entries = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final entry in entries) {
      if (!entry.path.endsWith('.yml') && !entry.path.endsWith('.yaml')) {
        continue;
      }
      final f = TextFile.read(entry.path, relativeTo: projectDir);
      if (f == null) continue;
      for (final m in f.allMatches(GradlePatterns.ciJavaVersion)) {
        out.add(
          Detected(int.parse(m.group(1)!), source: m.ref, raw: m.text.trim()),
        );
      }
    }
    return out;
  }
}

/// Reads `name:` from `pubspec.yaml`.
String? readPubspecName(String projectDir) {
  final f = File(p.join(projectDir, 'pubspec.yaml'));
  if (!f.existsSync()) return null;
  try {
    final doc = loadYaml(f.readAsStringSync());
    if (doc is Map) return doc['name']?.toString();
  } on Object {
    return null;
  }
  return null;
}
