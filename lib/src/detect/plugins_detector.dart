import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../model/plugin_info.dart';
import 'app_gradle_detector.dart';

/// Result of [PluginsDetector.detect].
class PluginsResult {
  /// Creates a result.
  const PluginsResult({
    this.plugins = const [],
    this.dartToolMissing = false,
    this.notes = const [],
  });

  /// Plugins that ship an Android Gradle module.
  final List<PluginInfo> plugins;

  /// True when `.dart_tool/package_config.json` does not exist.
  final bool dartToolMissing;

  /// Detection notes.
  final List<String> notes;
}

/// Lists every package in `.dart_tool/package_config.json` that has an
/// `android/build.gradle(.kts)` and inspects it.
class PluginsDetector {
  PluginsDetector._();

  /// Scans the dependency tree of the project at `projectDir`.
  static PluginsResult detect(String projectDir, {String? rootPackageName}) {
    final cfgFile = File(
      p.join(projectDir, '.dart_tool', 'package_config.json'),
    );
    if (!cfgFile.existsSync()) {
      return const PluginsResult(dartToolMissing: true);
    }
    final notes = <String>[];
    Map<String, Object?> cfg;
    try {
      cfg = jsonDecode(cfgFile.readAsStringSync()) as Map<String, Object?>;
    } on Object catch (e) {
      return PluginsResult(notes: ['cannot read package_config.json: $e']);
    }
    final lock = _readLock(projectDir);
    final root = rootPackageName ?? _pubspecName(projectDir);
    final cfgDir = cfgFile.parent.path;
    final out = <PluginInfo>[];

    final packages = cfg['packages'];
    if (packages is! List) return PluginsResult(notes: notes);
    for (final pkg in packages) {
      if (pkg is! Map) continue;
      final name = pkg['name']?.toString();
      final rootUri = pkg['rootUri']?.toString();
      if (name == null || rootUri == null || name == root) continue;
      final dir = _resolve(rootUri, cfgDir);
      if (dir == null) continue;
      if (p.equals(dir, projectDir)) continue;
      final androidDir = p.join(dir, 'android');
      final info = AppGradleDetector.detect(androidDir);
      if (!info.exists) continue;
      final lockEntry = lock[name];
      final version = lockEntry?.version ?? _versionFromDirName(dir, name);
      out.add(
        PluginInfo(
          name: name,
          rootPath: dir,
          version: version,
          buildFile: info.file!.path,
          appliesKgp: info.kgpApplied?.value ?? false,
          kgpRef: info.kgpApplied?.source,
          namespace: info.namespace?.value,
          jcenterRef: info.jcenterRefs.isEmpty ? null : info.jcenterRefs.first,
          compileSdkLiteral: info.compileSdk?.value.value,
          compileSdkRef: info.compileSdk?.source,
          javaCompatibility: info.sourceCompatibility?.value,
          javaCompatibilityRef: info.sourceCompatibility?.source,
          kgpClasspathVersion: info.kgpClasspathVersion?.value,
          kgpClasspathRef: info.kgpClasspathVersion?.source,
          isPathDependency:
              lockEntry?.source == 'path' ||
              (!rootUri.startsWith('file:') &&
                  !dir.contains('.pub-cache') &&
                  lockEntry == null),
          isDirectDependency:
              lockEntry?.dependency.startsWith('direct') ?? false,
        ),
      );
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return PluginsResult(plugins: out, notes: notes);
  }

  static String? _resolve(String rootUri, String cfgDir) {
    final uri = Uri.tryParse(rootUri);
    if (uri == null) return null;
    if (uri.hasScheme) {
      if (uri.scheme != 'file') return null;
      return p.normalize(uri.toFilePath(windows: Platform.isWindows));
    }
    return p.normalize(p.join(cfgDir, p.fromUri(uri)));
  }

  static String? _versionFromDirName(String dir, String name) {
    final base = p.basename(dir);
    if (base.startsWith('$name-')) return base.substring(name.length + 1);
    return null;
  }

  static String? _pubspecName(String projectDir) {
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

  static Map<String, _LockEntry> _readLock(String projectDir) {
    final f = File(p.join(projectDir, 'pubspec.lock'));
    if (!f.existsSync()) return const {};
    try {
      final doc = loadYaml(f.readAsStringSync());
      if (doc is! Map || doc['packages'] is! Map) return const {};
      final out = <String, _LockEntry>{};
      for (final e in (doc['packages'] as Map).entries) {
        final v = e.value;
        if (v is! Map) continue;
        out[e.key.toString()] = _LockEntry(
          version: v['version']?.toString(),
          dependency: v['dependency']?.toString() ?? '',
          source: v['source']?.toString(),
        );
      }
      return out;
    } on Object {
      return const {};
    }
  }
}

class _LockEntry {
  const _LockEntry({this.version, required this.dependency, this.source});
  final String? version;
  final String dependency;
  final String? source;
}
