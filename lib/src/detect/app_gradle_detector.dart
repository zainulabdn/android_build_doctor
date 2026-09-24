import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/project_snapshot.dart';
import '../model/sdk_level.dart';
import '../model/source_ref.dart';
import '../util/text_file.dart';
import '../util/versions.dart';
import 'gradle_patterns.dart';

/// What was read from an Android module's `build.gradle(.kts)` (the app
/// module, or a plugin's `android/` module).
class ModuleGradleInfo {
  /// Creates the info.
  const ModuleGradleInfo({
    this.file,
    this.kgpApplied,
    this.flutterPluginApply,
    this.namespace,
    this.compileSdk,
    this.targetSdk,
    this.minSdk,
    this.sourceCompatibility,
    this.targetCompatibility,
    this.jvmTarget,
    this.jvmToolchain,
    this.usesKotlinCompilerOptions = false,
    this.usesKotlinOptions = false,
    this.jcenterRefs = const [],
    this.kgpClasspathVersion,
  });

  /// The parsed build file, or `null` when missing.
  final TextFile? file;

  /// Whether the module applies KGP, and where.
  final Detected<bool>? kgpApplied;

  /// How the Flutter Gradle plugin is applied (app module only).
  final Detected<FlutterPluginApply>? flutterPluginApply;

  /// `namespace`.
  final Detected<String>? namespace;

  /// `compileSdk`.
  final Detected<SdkLevel>? compileSdk;

  /// `targetSdk`.
  final Detected<SdkLevel>? targetSdk;

  /// `minSdk`.
  final Detected<SdkLevel>? minSdk;

  /// Java `sourceCompatibility` major.
  final Detected<int>? sourceCompatibility;

  /// Java `targetCompatibility` major.
  final Detected<int>? targetCompatibility;

  /// Kotlin `jvmTarget` major.
  final Detected<int>? jvmTarget;

  /// `jvmToolchain(N)`.
  final Detected<int>? jvmToolchain;

  /// True when `kotlin { compilerOptions { } }` is used.
  final bool usesKotlinCompilerOptions;

  /// True when the legacy `kotlinOptions { }` is used.
  final bool usesKotlinOptions;

  /// `jcenter()` occurrences.
  final List<SourceRef> jcenterRefs;

  /// Legacy KGP classpath version in the module's own `buildscript`.
  final Detected<String>? kgpClasspathVersion;

  /// Whether the file exists.
  bool get exists => file != null;
}

/// Parses an Android module build file (`build.gradle` or `build.gradle.kts`).
class AppGradleDetector {
  AppGradleDetector._();

  /// Parses `<moduleDir>/build.gradle(.kts)`.
  static ModuleGradleInfo detect(String moduleDir, {String? relativeTo}) {
    final kts = p.join(moduleDir, 'build.gradle.kts');
    final groovy = p.join(moduleDir, 'build.gradle');
    final path = File(kts).existsSync()
        ? kts
        : File(groovy).existsSync()
        ? groovy
        : null;
    if (path == null) return const ModuleGradleInfo();
    final file = TextFile.read(path, relativeTo: relativeTo);
    if (file == null) return const ModuleGradleInfo();
    return parse(file);
  }

  /// Parses an already-loaded build file.
  static ModuleGradleInfo parse(TextFile file) {
    Detected<bool>? kgpApplied;
    for (final m in file.allMatches(GradlePatterns.kgpApply)) {
      if (m.text.contains('apply false')) continue;
      kgpApplied = Detected(true, source: m.ref, raw: m.text.trim());
      break;
    }

    Detected<FlutterPluginApply>? flutterApply;
    final decl = file.firstMatch(GradlePatterns.flutterPluginDeclarative);
    final imp = file.firstMatch(GradlePatterns.flutterPluginImperative);
    if (decl != null) {
      flutterApply = Detected(
        FlutterPluginApply.declarative,
        source: decl.ref,
        raw: decl.text.trim(),
      );
    } else if (imp != null) {
      flutterApply = Detected(
        FlutterPluginApply.imperative,
        source: imp.ref,
        raw: imp.text.trim(),
      );
    }

    final ns = file.firstMatch(GradlePatterns.namespace);
    final kgpCp = file.firstMatch(GradlePatterns.kgpClasspath);
    Detected<String>? kgpClasspath;
    if (kgpCp != null) {
      final r = GradlePatterns.resolveVariable(kgpCp.group(1)!, [file]);
      kgpClasspath = Detected(
        r.value,
        source: r.line == null ? kgpCp.ref : file.ref(r.line!),
        raw: kgpCp.text.trim(),
      );
    }

    return ModuleGradleInfo(
      file: file,
      kgpApplied: kgpApplied,
      flutterPluginApply: flutterApply,
      namespace: ns == null
          ? null
          : Detected(ns.group(1)!, source: ns.ref, raw: ns.text.trim()),
      compileSdk: _sdk(file, GradlePatterns.compileSdk),
      targetSdk: _sdk(file, GradlePatterns.targetSdk),
      minSdk: _sdk(file, GradlePatterns.minSdk),
      sourceCompatibility: _java(file, GradlePatterns.sourceCompatibility),
      targetCompatibility: _java(file, GradlePatterns.targetCompatibility),
      jvmTarget: _java(file, GradlePatterns.jvmTarget),
      jvmToolchain: _int(file, GradlePatterns.jvmToolchain),
      usesKotlinCompilerOptions:
          file.firstMatch(GradlePatterns.compilerOptions) != null,
      usesKotlinOptions: file.firstMatch(GradlePatterns.kotlinOptions) != null,
      jcenterRefs: [
        for (final m in file.allMatches(GradlePatterns.jcenter)) m.ref,
      ],
      kgpClasspathVersion: kgpClasspath,
    );
  }

  static Detected<SdkLevel>? _sdk(TextFile file, RegExp re) {
    final m = file.firstMatch(re);
    if (m == null) return null;
    final expr = GradlePatterns.cleanExpression(m.group(1)!);
    return Detected(
      SdkLevel(value: int.tryParse(expr), expression: expr),
      source: m.ref,
      raw: m.text.trim(),
    );
  }

  static Detected<int>? _java(TextFile file, RegExp re) {
    final m = file.firstMatch(re);
    if (m == null) return null;
    final major = Versions.javaMajor(m.group(1));
    if (major == null) return null;
    return Detected(major, source: m.ref, raw: m.text.trim());
  }

  static Detected<int>? _int(TextFile file, RegExp re) {
    final m = file.firstMatch(re);
    if (m == null) return null;
    final v = int.tryParse(m.group(1)!);
    if (v == null) return null;
    return Detected(v, source: m.ref, raw: m.text.trim());
  }
}
