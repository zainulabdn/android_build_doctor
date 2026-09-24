import '../model/source_ref.dart';
import '../util/text_file.dart';

/// A plugin or library entry in a version catalog.
class CatalogEntry {
  /// Creates an entry.
  const CatalogEntry({required this.alias, this.id, this.module, this.version});

  /// Alias as written in `[plugins]` / `[libraries]` (`android-application`).
  final String alias;

  /// Plugin id, for `[plugins]` entries.
  final String? id;

  /// `group:name`, for `[libraries]` entries.
  final String? module;

  /// Resolved version, pointing at the `[versions]` line when `version.ref`
  /// was used.
  final Detected<String>? version;
}

/// Minimal parser for `gradle/libs.versions.toml`. Handles the
/// `[versions]`, `[plugins]` and `[libraries]` tables with inline-table
/// syntax, which is all Flutter projects use.
class VersionCatalog {
  VersionCatalog._(this.file);

  /// Loads the catalog at `path`, or returns `null` when it does not exist.
  static VersionCatalog? load(String path, {String? relativeTo}) {
    final f = TextFile.read(path, relativeTo: relativeTo);
    if (f == null) return null;
    return VersionCatalog._(f).._parse();
  }

  /// The TOML file.
  final TextFile file;

  final Map<String, Detected<String>> _versions = {};
  final Map<String, CatalogEntry> _plugins = {};
  final Map<String, CatalogEntry> _libraries = {};

  static final RegExp _section = RegExp(r'^\s*\[([A-Za-z]+)\]');
  static final RegExp _versionLine = RegExp(
    r'''^\s*([A-Za-z0-9_.-]+)\s*=\s*["']([^"']+)["']''',
  );
  static final RegExp _entryLine = RegExp(
    r'^\s*([A-Za-z0-9_.-]+)\s*=\s*\{(.*)\}',
  );
  static final RegExp _kv = RegExp(
    r'''([A-Za-z0-9_.]+)\s*=\s*["']([^"']*)["']''',
  );

  void _parse() {
    String section = '';
    for (var i = 0; i < file.lines.length; i++) {
      final line = file.lines[i];
      final s = _section.firstMatch(line);
      if (s != null) {
        section = s.group(1)!;
        continue;
      }
      if (file.isCommentLine(i)) continue;
      if (section == 'versions') {
        final m = _versionLine.firstMatch(line);
        if (m != null) {
          _versions[m.group(1)!] = Detected(
            m.group(2)!,
            source: file.ref(i + 1),
            raw: line.trim(),
          );
        }
      } else if (section == 'plugins' || section == 'libraries') {
        final m = _entryLine.firstMatch(line);
        if (m == null) continue;
        final alias = m.group(1)!;
        final body = m.group(2)!;
        final kv = {
          for (final k in _kv.allMatches(body)) k.group(1)!: k.group(2)!,
        };
        Detected<String>? version;
        if (kv['version.ref'] != null) {
          version = _versions[kv['version.ref']!];
        } else if (kv['version'] != null) {
          version = Detected(
            kv['version']!,
            source: file.ref(i + 1),
            raw: line.trim(),
          );
        }
        final module =
            kv['module'] ??
            (kv['group'] != null && kv['name'] != null
                ? '${kv['group']}:${kv['name']}'
                : null);
        final entry = CatalogEntry(
          alias: alias,
          id: kv['id'],
          module: module,
          version: version,
        );
        (section == 'plugins' ? _plugins : _libraries)[alias] = entry;
      }
    }
  }

  /// A `[versions]` entry by key.
  Detected<String>? version(String key) => _versions[key];

  /// A `[plugins]` entry by alias. Accepts `android.application` (as used
  /// in `libs.plugins.android.application`) or `android-application`.
  CatalogEntry? plugin(String alias) =>
      _plugins[alias] ??
      _plugins[alias.replaceAll('.', '-')] ??
      _plugins[alias.replaceAll('.', '_')];

  /// The AGP version, from a plugin id or the classic Maven coordinate.
  Detected<String>? get agpVersion {
    for (final e in _plugins.values) {
      if (e.id == 'com.android.application' || e.id == 'com.android.library') {
        if (e.version != null) return e.version;
      }
    }
    for (final e in _libraries.values) {
      if (e.module == 'com.android.tools.build:gradle' && e.version != null) {
        return e.version;
      }
    }
    return _versions['agp'];
  }

  /// The KGP version, from a plugin id or the classic Maven coordinate.
  Detected<String>? get kgpVersion {
    for (final e in _plugins.values) {
      if (e.id == 'org.jetbrains.kotlin.android' && e.version != null) {
        return e.version;
      }
    }
    for (final e in _libraries.values) {
      if (e.module == 'org.jetbrains.kotlin:kotlin-gradle-plugin' &&
          e.version != null) {
        return e.version;
      }
    }
    return _versions['kotlin'];
  }
}
