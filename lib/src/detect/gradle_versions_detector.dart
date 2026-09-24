import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/project_snapshot.dart';
import '../model/source_ref.dart';
import '../util/text_file.dart';
import 'gradle_patterns.dart';
import 'version_catalog.dart';

/// Result of [GradleVersionsDetector.detect].
class GradleVersions {
  /// Creates a result.
  const GradleVersions({
    this.agp,
    this.kgp,
    this.style,
    this.jcenterRefs = const [],
    this.catalog,
    this.legacyPluginLoaderRef,
  });

  /// AGP version with its declaration site.
  final Detected<String>? agp;

  /// KGP version with its declaration site.
  final Detected<String>? kgp;

  /// How the versions are declared.
  final GradleDeclarationStyle? style;

  /// Every `jcenter()` occurrence in the project's Gradle files.
  final List<SourceRef> jcenterRefs;

  /// The version catalog, when one exists.
  final VersionCatalog? catalog;

  /// `apply from: ".../app_plugin_loader.gradle"` in settings, if present.
  final SourceRef? legacyPluginLoaderRef;
}

/// Finds the AGP and KGP versions in `settings.gradle(.kts)`,
/// `build.gradle(.kts)` (legacy `buildscript` classpath) and
/// `gradle/libs.versions.toml`.
class GradleVersionsDetector {
  GradleVersionsDetector._();

  static final RegExp _legacyLoader = RegExp(
    r'''apply\s+from:\s*["'][^"']*app_plugin_loader\.gradle["']''',
  );

  /// Detects versions for the Gradle root at `androidDir`.
  static GradleVersions detect(String androidDir, {String? projectDir}) {
    final rel = projectDir ?? p.dirname(androidDir);
    final settings = _readEither(androidDir, 'settings.gradle', rel);
    final rootBuild = _readEither(androidDir, 'build.gradle', rel);
    final appBuild = _readEither(
      p.join(androidDir, 'app'),
      'build.gradle',
      rel,
    );
    final catalog = VersionCatalog.load(
      p.join(androidDir, 'gradle', 'libs.versions.toml'),
      relativeTo: rel,
    );
    final files = [
      settings,
      rootBuild,
      appBuild,
    ].whereType<TextFile>().toList();

    Detected<String>? agp;
    Detected<String>? kgp;
    GradleDeclarationStyle? style;

    // 1. Declarative plugins block (settings.gradle(.kts), sometimes root build).
    for (final f in files) {
      agp ??= _resolved(
        f,
        f.firstMatch(GradlePatterns.agpPluginVersion),
        files,
      );
      kgp ??= _resolved(
        f,
        f.firstMatch(GradlePatterns.kgpPluginVersion),
        files,
      );
    }
    if (agp != null || kgp != null) style = GradleDeclarationStyle.pluginsBlock;

    // 2. Version catalog via alias(libs.plugins.x).
    if (catalog != null) {
      for (final f in files) {
        for (final m in f.allMatches(GradlePatterns.aliasPlugin)) {
          final alias = m.group(1)!;
          final plugin = catalog.plugin(alias);
          if (plugin == null) continue;
          if (plugin.id == 'com.android.application' ||
              plugin.id == 'com.android.library') {
            if (agp == null && plugin.version != null) {
              agp = plugin.version;
              style = GradleDeclarationStyle.versionCatalog;
            }
          } else if (plugin.id == 'org.jetbrains.kotlin.android') {
            if (kgp == null && plugin.version != null) {
              kgp = plugin.version;
              style ??= GradleDeclarationStyle.versionCatalog;
            }
          }
        }
      }
      // Catalog present but not referenced through alias(): still use it.
      agp ??= catalog.agpVersion;
      kgp ??= catalog.kgpVersion;
      if (style == null && (agp != null || kgp != null)) {
        style = GradleDeclarationStyle.versionCatalog;
      }
    }

    // 3. Legacy buildscript classpath.
    for (final f in files) {
      if (agp == null) {
        final m = f.firstMatch(GradlePatterns.agpClasspath);
        if (m != null) {
          agp = _resolved(f, m, files);
          style ??= GradleDeclarationStyle.buildscriptClasspath;
        }
      }
      if (kgp == null) {
        final m = f.firstMatch(GradlePatterns.kgpClasspath);
        if (m != null) {
          kgp = _resolved(f, m, files);
          style ??= GradleDeclarationStyle.buildscriptClasspath;
        }
      }
    }

    final jcenter = <SourceRef>[
      for (final f in files)
        for (final m in f.allMatches(GradlePatterns.jcenter)) m.ref,
    ];

    final loader = settings?.firstMatch(_legacyLoader);

    return GradleVersions(
      agp: agp,
      kgp: kgp,
      style: style,
      jcenterRefs: jcenter,
      catalog: catalog,
      legacyPluginLoaderRef: loader?.ref,
    );
  }

  static TextFile? _readEither(String dir, String base, String relativeTo) {
    final kts = p.join(dir, '$base.kts');
    final groovy = p.join(dir, base);
    if (File(kts).existsSync()) {
      return TextFile.read(kts, relativeTo: relativeTo);
    }
    if (File(groovy).existsSync()) {
      return TextFile.read(groovy, relativeTo: relativeTo);
    }
    return null;
  }

  /// Turns a match into a [Detected] value, resolving `$variable`
  /// references against definitions in any of `files`.
  static Detected<String>? _resolved(
    TextFile file,
    LineMatch? m,
    List<TextFile> files,
  ) {
    if (m == null) return null;
    final r = GradlePatterns.resolveVariable(m.group(1)!, files);
    if (r.line != null && r.file != null) {
      return Detected(
        r.value,
        source: r.file!.ref(r.line!),
        raw: r.file!.lines[r.line! - 1].trim(),
      );
    }
    return Detected(r.value, source: m.ref, raw: m.text.trim());
  }
}
