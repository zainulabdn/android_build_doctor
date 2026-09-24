import '../model/finding.dart';
import '../model/plugin_info.dart';
import '../model/severity.dart';
import '../util/versions.dart';
import 'docs.dart';
import 'gd_rules.dart';
import 'rule.dart';

String _label(PluginInfo p) =>
    p.version == null ? p.name : '${p.name} ${p.version}';

String _upgradeHint(PluginInfo p) {
  final latest = p.latestVersion;
  if (latest == null || p.version == null) {
    return '';
  }
  if (Versions.compare(latest, p.version!) <= 0) {
    return ' You already have the newest release.';
  }
  return ' A newer version exists (${p.version} -> $latest); it may fix this.';
}

/// GP001: plugin applies the Kotlin Gradle Plugin.
class Gp001PluginAppliesKgp extends Rule {
  /// Creates the rule.
  const Gp001PluginAppliesKgp();

  @override
  String get id => 'GP001';

  @override
  String get description =>
      'Plugin applies kotlin-android (blocks built-in Kotlin)';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    final strict =
        Checks.agpHasBuiltInKotlin(ctx) && (s.builtInKotlin?.value ?? false);
    final agp9NoFlag =
        Checks.agpHasBuiltInKotlin(ctx) && s.builtInKotlin == null;
    return [
      for (final p in s.plugins)
        if (p.appliesKgp)
          Finding(
            id: id,
            severity: strict || agp9NoFlag ? Severity.error : Severity.warning,
            message:
                '${_label(p)} still applies the Kotlin Gradle Plugin. '
                '${strict
                    ? 'With android.builtInKotlin=true this breaks the build.'
                    : agp9NoFlag
                    ? 'On AGP 9 without android.builtInKotlin=false this breaks the build.'
                    : 'It blocks enabling built-in Kotlin (AGP 9).'}',
            fix:
                'Upgrade the plugin to a release migrated to built-in Kotlin, or '
                'ask the author to migrate (issue template in the docs).'
                '${_upgradeHint(p)}',
            docs: Docs.builtInKotlinPlugin,
            source: p.kgpRef,
            data: {
              'plugin': p.name,
              'version': p.version,
              'latest': p.latestVersion,
            },
          ),
    ];
  }
}

/// GP002: plugin has no `namespace`.
class Gp002PluginMissingNamespace extends Rule {
  /// Creates the rule.
  const Gp002PluginMissingNamespace();

  @override
  String get id => 'GP002';

  @override
  String get description => 'Plugin has no namespace (breaks on AGP 8+)';

  @override
  List<Finding> evaluate(RuleContext ctx) => [
    for (final p in ctx.snapshot.plugins)
      if (p.missingNamespace)
        Finding(
          id: id,
          severity: Severity.error,
          message:
              '${_label(p)} declares no namespace in its build.gradle. '
              'AGP 8+ fails with "Namespace not specified".',
          fix:
              'Upgrade the plugin; releases that support AGP 8 add the '
              'namespace.${_upgradeHint(p)}',
          docs: Docs.namespace,
          source: p.buildFile == null ? null : p.kgpRef ?? p.compileSdkRef,
          data: {
            'plugin': p.name,
            'version': p.version,
            'latest': p.latestVersion,
          },
        ),
  ];
}

/// GP003: plugin uses `jcenter()`.
class Gp003PluginJcenter extends Rule {
  /// Creates the rule.
  const Gp003PluginJcenter();

  @override
  String get id => 'GP003';

  @override
  String get description => 'Plugin lists jcenter()';

  @override
  List<Finding> evaluate(RuleContext ctx) => [
    for (final p in ctx.snapshot.plugins)
      if (p.jcenterRef != null)
        Finding(
          id: id,
          severity: Severity.warning,
          message: '${_label(p)} lists jcenter(), which shut down in 2022.',
          fix:
              'Upgrade the plugin or ask the author to switch to '
              'mavenCentral().${_upgradeHint(p)}',
          docs: Docs.jcenter,
          source: p.jcenterRef,
          data: {
            'plugin': p.name,
            'version': p.version,
            'latest': p.latestVersion,
          },
        ),
  ];
}

/// GP004: plugin hard-codes an old compileSdk, Java 8 or an old KGP classpath.
class Gp004PluginOldSettings extends Rule {
  /// Creates the rule.
  const Gp004PluginOldSettings();

  @override
  String get id => 'GP004';

  @override
  String get description => 'Plugin hard-codes old compileSdk / Java / KGP';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    final defCompile = ctx.release?.defaults.compileSdk;
    final minKgp = ctx.release?.minimums.kgp;
    final out = <Finding>[];
    for (final p in s.plugins) {
      final sdk = p.compileSdkLiteral;
      if (sdk != null &&
          defCompile != null &&
          sdk < defCompile - ctx.matrix.pluginCompileSdkLag) {
        out.add(
          Finding(
            id: id,
            severity: Severity.warning,
            message:
                '${_label(p)} hard-codes compileSdk $sdk '
                '(${ctx.flutterLabel} default is $defCompile). It may not '
                'compile against newer AndroidX libraries.',
            fix: 'Upgrade the plugin.${_upgradeHint(p)}',
            docs: Docs.gradleConfig,
            source: p.compileSdkRef,
            data: {'plugin': p.name, 'compile_sdk': sdk, 'default': defCompile},
          ),
        );
      }
      final java = p.javaCompatibility;
      if (java != null && java < ctx.matrix.pluginJavaBelow) {
        out.add(
          Finding(
            id: id,
            severity: Severity.warning,
            message:
                '${_label(p)} targets Java $java. Modern JDKs warn that '
                'source/target $java is obsolete and will drop it.',
            fix: 'Upgrade the plugin.${_upgradeHint(p)}',
            docs: Docs.javaGradle,
            source: p.javaCompatibilityRef,
            data: {'plugin': p.name, 'java': java},
          ),
        );
      }
      final kgp = p.kgpClasspathVersion;
      if (kgp != null &&
          minKgp != null &&
          Versions.parse(kgp) != null &&
          Versions.isBelow(kgp, minKgp)) {
        out.add(
          Finding(
            id: id,
            severity: Severity.warning,
            message:
                '${_label(p)} pins Kotlin Gradle Plugin $kgp on its '
                'buildscript classpath; ${ctx.flutterLabel} requires >= $minKgp.',
            fix: 'Upgrade the plugin.${_upgradeHint(p)}',
            docs: Docs.kotlinVersion,
            source: p.kgpClasspathRef,
            data: {'plugin': p.name, 'kgp': kgp, 'min_kgp': minKgp},
          ),
        );
      }
    }
    return out;
  }
}

/// GP005: a newer version of the plugin exists on pub.dev.
class Gp005PluginOutdated extends Rule {
  /// Creates the rule.
  const Gp005PluginOutdated();

  @override
  String get id => 'GP005';

  @override
  String get description => 'Newer plugin version available on pub.dev';

  @override
  List<Finding> evaluate(RuleContext ctx) => [
    for (final p in ctx.snapshot.plugins)
      if (p.latestVersion != null &&
          p.version != null &&
          Versions.compare(p.latestVersion!, p.version!) > 0)
        Finding(
          id: id,
          severity: Severity.info,
          message:
              '${_label(p)} -> ${p.latestVersion} is available on pub.dev.',
          fix:
              'Upgrade ${p.name} to ${p.latestVersion}; newer versions may fix '
              'the issues above (the tool cannot know without scanning it).',
          docs: 'https://pub.dev/packages/${p.name}/changelog',
          data: {
            'plugin': p.name,
            'version': p.version,
            'latest': p.latestVersion,
          },
        ),
  ];
}
