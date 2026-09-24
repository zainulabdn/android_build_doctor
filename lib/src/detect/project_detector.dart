import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/project_snapshot.dart';
import '../model/source_ref.dart';
import '../util/process.dart';
import 'app_gradle_detector.dart';
import 'flutter_detector.dart';
import 'gradle_properties_detector.dart';
import 'gradle_versions_detector.dart';
import 'java_detector.dart';
import 'misc_detectors.dart';
import 'plugins_detector.dart';
import 'wrapper_detector.dart';

/// Runs every detector and assembles a [ProjectSnapshot].
class ProjectDetector {
  /// Creates a detector. `run` executes external commands (`flutter`, `java`,
  /// `git`); pass [noProcess] to disable them.
  ProjectDetector({RunProcess? run, Map<String, String>? environment})
    : run = run ?? defaultRunProcess,
      environment = environment ?? Platform.environment;

  /// Command runner.
  final RunProcess run;

  /// Environment variables (for `JAVA_HOME`, `HOME`).
  final Map<String, String> environment;

  /// Whether `projectDir` looks like a Flutter/Dart project.
  static bool isProject(String projectDir) =>
      File(p.join(projectDir, 'pubspec.yaml')).existsSync();

  /// Detects everything about the project at `projectDir`.
  ///
  /// With `scanPlugins`, the dependency tree is scanned too (slower on big
  /// projects, needs `.dart_tool/`).
  Future<ProjectSnapshot> detect(
    String projectDir, {
    bool scanPlugins = false,
  }) async {
    final dir = p.normalize(p.absolute(projectDir));
    final androidDir = p.join(dir, 'android');
    final hasAndroid = Directory(androidDir).existsSync();
    final notes = <String>[];

    final flutterInfo = await FlutterDetector.detect(dir, run: run);
    notes.addAll(flutterInfo.notes);

    if (!hasAndroid) {
      return ProjectSnapshot(
        projectDir: dir,
        projectName: readPubspecName(dir),
        hasAndroidDir: false,
        flutterVersion: flutterInfo.flutterVersion,
        flutterVersionSource: flutterInfo.source,
        dartVersion: flutterInfo.dartVersion,
        flutterRoot: flutterInfo.flutterRoot,
        notes: notes,
      );
    }

    final props = GradlePropertiesDetector(androidDir, projectDir: dir);
    final versions = GradleVersionsDetector.detect(androidDir, projectDir: dir);
    final app = AppGradleDetector.detect(
      p.join(androidDir, 'app'),
      relativeTo: dir,
    );
    if (!app.exists) notes.add('android/app/build.gradle(.kts) not found');

    final javaInfo = await JavaDetector.detect(
      gradleJavaHome: props.javaHome,
      flutterExecutable:
          flutterInfo.executable ?? FlutterDetector.flutterExecutable,
      run: run,
      environment: environment,
    );
    notes.addAll(javaInfo.notes);

    Detected<String>? createdWith;
    final meta = MetadataDetector.detect(dir);
    if (meta != null) {
      final v = await FlutterDetector.versionForRevision(
        meta.revision,
        flutterInfo.flutterRoot,
        run: run,
      );
      if (v != null) {
        createdWith = Detected(v, source: meta.ref, raw: meta.revision);
      } else {
        notes.add(
          '.metadata revision ${meta.revision.substring(0, meta.revision.length.clamp(0, 10))} '
          'could not be mapped to a Flutter version',
        );
      }
    }

    var snapshot = ProjectSnapshot(
      projectDir: dir,
      projectName: readPubspecName(dir),
      hasAndroidDir: true,
      flutterVersion: flutterInfo.flutterVersion,
      flutterVersionSource: flutterInfo.source,
      dartVersion: flutterInfo.dartVersion,
      flutterRoot: flutterInfo.flutterRoot,
      createdWithFlutter: createdWith,
      gradleVersion: WrapperDetector.detect(androidDir, projectDir: dir),
      agpVersion: versions.agp,
      kgpVersion: versions.kgp,
      declarationStyle: versions.style,
      kgpApplied: app.kgpApplied ?? (app.exists ? const Detected(false) : null),
      builtInKotlin: props.builtInKotlin,
      newDsl: props.newDsl,
      gradleJavaHome: props.javaHome,
      javaVersion: javaInfo.version,
      javaSource: javaInfo.source,
      javaHome: javaInfo.home,
      compileSdk: app.compileSdk,
      targetSdk: app.targetSdk,
      minSdk: app.minSdk,
      sourceCompatibility: app.sourceCompatibility,
      targetCompatibility: app.targetCompatibility,
      jvmTarget: app.jvmTarget,
      jvmToolchain: app.jvmToolchain,
      usesKotlinCompilerOptions: app.usesKotlinCompilerOptions,
      namespace: app.namespace,
      manifestPackage: ManifestDetector.detect(androidDir, projectDir: dir),
      flutterPluginApply: app.flutterPluginApply,
      legacyPluginLoaderRef: versions.legacyPluginLoaderRef,
      jcenterRefs: {...versions.jcenterRefs, ...app.jcenterRefs}.toList(),
      ciJavaVersions: CiDetector.detect(dir),
      notes: notes,
    );

    if (scanPlugins) {
      final plugins = PluginsDetector.detect(
        dir,
        rootPackageName: snapshot.projectName,
      );
      snapshot = snapshot.copyWith(
        plugins: plugins.plugins,
        pluginsScanned: true,
        dartToolMissing: plugins.dartToolMissing,
        notes: [...snapshot.notes, ...plugins.notes],
      );
    }
    return snapshot;
  }
}
