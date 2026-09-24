import '../util/paths.dart';
import 'source_ref.dart';

/// What was learned about one Flutter plugin's Android side.
class PluginInfo {
  /// Creates a plugin description.
  const PluginInfo({
    required this.name,
    required this.rootPath,
    this.version,
    this.buildFile,
    this.appliesKgp = false,
    this.kgpRef,
    this.namespace,
    this.jcenterRef,
    this.compileSdkLiteral,
    this.compileSdkRef,
    this.javaCompatibility,
    this.javaCompatibilityRef,
    this.kgpClasspathVersion,
    this.kgpClasspathRef,
    this.usesFlutterBuildDir = false,
    this.isPathDependency = false,
    this.isDirectDependency = false,
    this.latestVersion,
  });

  /// pub package name.
  final String name;

  /// Absolute path of the package root.
  final String rootPath;

  /// Installed version from `pubspec.lock` (or the pub cache folder name).
  final String? version;

  /// Path of `android/build.gradle` or `android/build.gradle.kts`.
  final String? buildFile;

  /// True when the plugin applies the Kotlin Gradle Plugin (`kotlin-android`).
  final bool appliesKgp;

  /// Where the KGP apply was found.
  final SourceRef? kgpRef;

  /// The plugin's `namespace`, or `null` when missing.
  final String? namespace;

  /// Where `jcenter()` was found, or `null` when it is not used.
  final SourceRef? jcenterRef;

  /// Hard-coded numeric `compileSdk`, if any.
  final int? compileSdkLiteral;

  /// Where the hard-coded `compileSdk` was found.
  final SourceRef? compileSdkRef;

  /// `sourceCompatibility` Java major version, if declared.
  final int? javaCompatibility;

  /// Where `sourceCompatibility` was found.
  final SourceRef? javaCompatibilityRef;

  /// KGP version from a legacy `classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:X"`.
  final String? kgpClasspathVersion;

  /// Where the KGP classpath was found.
  final SourceRef? kgpClasspathRef;

  /// Whether the plugin sets `buildDir`/`layout.buildDirectory` (informational).
  final bool usesFlutterBuildDir;

  /// True for `path:` dependencies (not in the pub cache).
  final bool isPathDependency;

  /// True when listed directly in the app's `pubspec.yaml`.
  final bool isDirectDependency;

  /// Newest version on pub.dev, when looked up.
  final String? latestVersion;

  /// True when the plugin ships an Android Gradle build file.
  bool get hasAndroidBuild => buildFile != null;

  /// True when the plugin has no `namespace` declaration.
  bool get missingNamespace => buildFile != null && namespace == null;

  /// Copy with a pub.dev `latestVersion` filled in.
  PluginInfo withLatestVersion(String? latest) => PluginInfo(
    name: name,
    rootPath: rootPath,
    version: version,
    buildFile: buildFile,
    appliesKgp: appliesKgp,
    kgpRef: kgpRef,
    namespace: namespace,
    jcenterRef: jcenterRef,
    compileSdkLiteral: compileSdkLiteral,
    compileSdkRef: compileSdkRef,
    javaCompatibility: javaCompatibility,
    javaCompatibilityRef: javaCompatibilityRef,
    kgpClasspathVersion: kgpClasspathVersion,
    kgpClasspathRef: kgpClasspathRef,
    usesFlutterBuildDir: usesFlutterBuildDir,
    isPathDependency: isPathDependency,
    isDirectDependency: isDirectDependency,
    latestVersion: latest,
  );

  /// JSON representation used by `--json` output.
  Map<String, Object?> toJson() => {
    'name': name,
    'version': version,
    'latest_version': latestVersion,
    'root': toPosixPath(rootPath),
    'build_file': buildFile == null ? null : toPosixPath(buildFile!),
    'applies_kgp': appliesKgp,
    'kgp_ref': kgpRef?.toJson(),
    'namespace': namespace,
    'uses_jcenter': jcenterRef != null,
    'compile_sdk_literal': compileSdkLiteral,
    'java_compatibility': javaCompatibility,
    'kgp_classpath_version': kgpClasspathVersion,
    'is_path_dependency': isPathDependency,
    'is_direct_dependency': isDirectDependency,
  };
}
