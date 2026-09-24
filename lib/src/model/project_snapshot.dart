import 'plugin_info.dart';
import 'sdk_level.dart';
import 'source_ref.dart';

/// How the Flutter Gradle plugin is applied in `android/app/build.gradle(.kts)`.
enum FlutterPluginApply {
  /// `id "dev.flutter.flutter-gradle-plugin"` (current).
  declarative,

  /// `apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"` (deprecated).
  imperative,
}

/// Where the AGP / KGP versions are declared.
enum GradleDeclarationStyle {
  /// `plugins { id "com.android.application" version "X" }` in settings.
  pluginsBlock,

  /// `buildscript { dependencies { classpath "com.android.tools.build:gradle:X" } }`.
  buildscriptClasspath,

  /// `libs.versions.toml` version catalog.
  versionCatalog,
}

/// Everything the detectors learned about a project. Pure data; rules are
/// functions of this object.
class ProjectSnapshot {
  /// Creates a snapshot.
  const ProjectSnapshot({
    required this.projectDir,
    this.projectName,
    this.hasAndroidDir = false,
    this.flutterVersion,
    this.flutterVersionSource,
    this.dartVersion,
    this.flutterRoot,
    this.createdWithFlutter,
    this.gradleVersion,
    this.agpVersion,
    this.kgpVersion,
    this.declarationStyle,
    this.kgpApplied,
    this.builtInKotlin,
    this.newDsl,
    this.gradleJavaHome,
    this.javaVersion,
    this.javaSource,
    this.javaHome,
    this.compileSdk,
    this.targetSdk,
    this.minSdk,
    this.sourceCompatibility,
    this.targetCompatibility,
    this.jvmTarget,
    this.jvmToolchain,
    this.usesKotlinCompilerOptions = false,
    this.namespace,
    this.manifestPackage,
    this.flutterPluginApply,
    this.legacyPluginLoaderRef,
    this.jcenterRefs = const [],
    this.ciJavaVersions = const [],
    this.plugins = const [],
    this.pluginsScanned = false,
    this.dartToolMissing = false,
    this.notes = const [],
  });

  /// Absolute project root (where `pubspec.yaml` lives).
  final String projectDir;

  /// `name:` from `pubspec.yaml`.
  final String? projectName;

  /// Whether `android/` exists.
  final bool hasAndroidDir;

  /// Flutter SDK version in use (for example `3.47.1`).
  final Detected<String>? flutterVersion;

  /// Human description of where the Flutter version came from.
  final String? flutterVersionSource;

  /// Dart SDK version in use.
  final Detected<String>? dartVersion;

  /// Path of the Flutter SDK, when known.
  final String? flutterRoot;

  /// Flutter version the project was created with (from `.metadata`).
  final Detected<String>? createdWithFlutter;

  /// Gradle wrapper version.
  final Detected<String>? gradleVersion;

  /// Android Gradle Plugin version.
  final Detected<String>? agpVersion;

  /// Kotlin Gradle Plugin version declared for the project.
  final Detected<String>? kgpVersion;

  /// How AGP / KGP are declared.
  final GradleDeclarationStyle? declarationStyle;

  /// Whether the app module applies `kotlin-android` / KGP, and where.
  final Detected<bool>? kgpApplied;

  /// `android.builtInKotlin` from `gradle.properties`.
  final Detected<bool>? builtInKotlin;

  /// `android.newDsl` from `gradle.properties`.
  final Detected<bool>? newDsl;

  /// `org.gradle.java.home` from `gradle.properties`.
  final Detected<String>? gradleJavaHome;

  /// Major version of the JDK that will run Gradle.
  final Detected<int>? javaVersion;

  /// Where the JDK was found (`gradle.properties`, `flutter config`, ...).
  final String? javaSource;

  /// Path of that JDK.
  final String? javaHome;

  /// `compileSdk` of the app module.
  final Detected<SdkLevel>? compileSdk;

  /// `targetSdk` of the app module.
  final Detected<SdkLevel>? targetSdk;

  /// `minSdk` of the app module.
  final Detected<SdkLevel>? minSdk;

  /// `compileOptions.sourceCompatibility` Java major.
  final Detected<int>? sourceCompatibility;

  /// `compileOptions.targetCompatibility` Java major.
  final Detected<int>? targetCompatibility;

  /// Kotlin `jvmTarget` Java major.
  final Detected<int>? jvmTarget;

  /// `kotlin { jvmToolchain(N) }` value.
  final Detected<int>? jvmToolchain;

  /// True when the app uses the new `kotlin { compilerOptions { } }` block.
  final bool usesKotlinCompilerOptions;

  /// `namespace` of the app module.
  final Detected<String>? namespace;

  /// `package` attribute of `AndroidManifest.xml` (fallback namespace).
  final Detected<String>? manifestPackage;

  /// How the Flutter Gradle plugin is applied.
  final Detected<FlutterPluginApply>? flutterPluginApply;

  /// `apply from: ".../app_plugin_loader.gradle"` in settings.gradle (deprecated).
  final SourceRef? legacyPluginLoaderRef;

  /// Every `jcenter()` occurrence in the app's Gradle files.
  final List<SourceRef> jcenterRefs;

  /// `java-version:` values found in `.github/workflows/*.yml`.
  final List<Detected<int>> ciJavaVersions;

  /// Android plugins in the dependency tree (only when scanned).
  final List<PluginInfo> plugins;

  /// Whether the plugin scan ran.
  final bool pluginsScanned;

  /// True when `.dart_tool/package_config.json` is missing.
  final bool dartToolMissing;

  /// Non-fatal detection notes (tool not found, file unreadable, ...).
  final List<String> notes;

  /// Plugins that still apply KGP (AGP 9 / built-in Kotlin blockers).
  List<PluginInfo> get kgpPlugins =>
      plugins.where((p) => p.appliesKgp).toList();

  /// Copy with a different plugin list.
  ProjectSnapshot withPlugins(List<PluginInfo> plugins) =>
      copyWith(plugins: plugins, pluginsScanned: true);

  /// Copy with some fields replaced.
  ProjectSnapshot copyWith({
    Detected<String>? flutterVersion,
    String? flutterVersionSource,
    Detected<String>? dartVersion,
    String? flutterRoot,
    Detected<String>? createdWithFlutter,
    Detected<int>? javaVersion,
    String? javaSource,
    String? javaHome,
    List<PluginInfo>? plugins,
    bool? pluginsScanned,
    bool? dartToolMissing,
    List<String>? notes,
  }) => ProjectSnapshot(
    projectDir: projectDir,
    projectName: projectName,
    hasAndroidDir: hasAndroidDir,
    flutterVersion: flutterVersion ?? this.flutterVersion,
    flutterVersionSource: flutterVersionSource ?? this.flutterVersionSource,
    dartVersion: dartVersion ?? this.dartVersion,
    flutterRoot: flutterRoot ?? this.flutterRoot,
    createdWithFlutter: createdWithFlutter ?? this.createdWithFlutter,
    gradleVersion: gradleVersion,
    agpVersion: agpVersion,
    kgpVersion: kgpVersion,
    declarationStyle: declarationStyle,
    kgpApplied: kgpApplied,
    builtInKotlin: builtInKotlin,
    newDsl: newDsl,
    gradleJavaHome: gradleJavaHome,
    javaVersion: javaVersion ?? this.javaVersion,
    javaSource: javaSource ?? this.javaSource,
    javaHome: javaHome ?? this.javaHome,
    compileSdk: compileSdk,
    targetSdk: targetSdk,
    minSdk: minSdk,
    sourceCompatibility: sourceCompatibility,
    targetCompatibility: targetCompatibility,
    jvmTarget: jvmTarget,
    jvmToolchain: jvmToolchain,
    usesKotlinCompilerOptions: usesKotlinCompilerOptions,
    namespace: namespace,
    manifestPackage: manifestPackage,
    flutterPluginApply: flutterPluginApply,
    legacyPluginLoaderRef: legacyPluginLoaderRef,
    jcenterRefs: jcenterRefs,
    ciJavaVersions: ciJavaVersions,
    plugins: plugins ?? this.plugins,
    pluginsScanned: pluginsScanned ?? this.pluginsScanned,
    dartToolMissing: dartToolMissing ?? this.dartToolMissing,
    notes: notes ?? this.notes,
  );

  /// JSON representation of the detected versions used by `--json` output.
  Map<String, Object?> toJson() => {
    'project_dir': projectDir,
    'project_name': projectName,
    'has_android_dir': hasAndroidDir,
    'flutter': flutterVersion?.toJson(),
    'flutter_source': flutterVersionSource,
    'dart': dartVersion?.toJson(),
    'flutter_root': flutterRoot,
    'created_with_flutter': createdWithFlutter?.toJson(),
    'gradle': gradleVersion?.toJson(),
    'agp': agpVersion?.toJson(),
    'kgp': kgpVersion?.toJson(),
    'declaration_style': declarationStyle?.name,
    'kgp_applied': kgpApplied?.toJson(),
    'built_in_kotlin': builtInKotlin?.toJson(),
    'new_dsl': newDsl?.toJson(),
    'gradle_java_home': gradleJavaHome?.toJson(),
    'java': javaVersion?.toJson(),
    'java_source': javaSource,
    'java_home': javaHome,
    'compile_sdk': compileSdk == null
        ? null
        : {...compileSdk!.value.toJson(), ...?compileSdk!.source?.toJson()},
    'target_sdk': targetSdk == null
        ? null
        : {...targetSdk!.value.toJson(), ...?targetSdk!.source?.toJson()},
    'min_sdk': minSdk == null
        ? null
        : {...minSdk!.value.toJson(), ...?minSdk!.source?.toJson()},
    'source_compatibility': sourceCompatibility?.toJson(),
    'target_compatibility': targetCompatibility?.toJson(),
    'jvm_target': jvmTarget?.toJson(),
    'jvm_toolchain': jvmToolchain?.toJson(),
    'uses_kotlin_compiler_options': usesKotlinCompilerOptions,
    'namespace': namespace?.toJson(),
    'manifest_package': manifestPackage?.toJson(),
    'flutter_plugin_apply': flutterPluginApply?.value.name,
    'legacy_plugin_loader': legacyPluginLoaderRef?.toJson(),
    'jcenter': jcenterRefs.map((r) => r.toJson()).toList(),
    'ci_java_versions': ciJavaVersions.map((d) => d.toJson()).toList(),
    'plugins_scanned': pluginsScanned,
    'plugins': plugins.map((p) => p.toJson()).toList(),
    'dart_tool_missing': dartToolMissing,
    'notes': notes,
  };
}
