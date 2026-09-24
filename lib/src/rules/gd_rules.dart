import '../model/finding.dart';
import '../model/project_snapshot.dart';
import '../model/source_ref.dart';
import '../model/severity.dart';
import '../util/versions.dart';
import 'docs.dart';
import 'rule.dart';

/// Shared version checks so that rules stay independent yet consistent.
class Checks {
  Checks._();

  /// The hard minimum Java for the project: the highest of Flutter's
  /// minimum, AGP's minimum JDK and Gradle's minimum JVM. Returns the value
  /// and the constraint's description.
  static ({int java, String because})? minJava(RuleContext ctx) {
    final s = ctx.snapshot;
    ({int java, String because})? best;
    void consider(int? v, String because) {
      if (v == null) return;
      if (best == null || v > best!.java) best = (java: v, because: because);
    }

    consider(
      int.tryParse(ctx.release?.minimums.java ?? ''),
      '${ctx.flutterLabel} requires Java ${ctx.release?.minimums.java}',
    );
    final agp = s.agpVersion?.value;
    consider(
      ctx.matrix.minJdkForAgp(agp),
      'AGP $agp requires JDK ${ctx.matrix.minJdkForAgp(agp)}',
    );
    final gradle = s.gradleVersion?.value;
    consider(
      ctx.matrix.minJavaForGradle(gradle),
      'Gradle $gradle needs Java ${ctx.matrix.minJavaForGradle(gradle)} to run',
    );
    return best;
  }

  /// True when Gradle is below what the AGP version needs.
  static String? gradleBelowAgp(RuleContext ctx) {
    final s = ctx.snapshot;
    final gradle = s.gradleVersion?.value;
    final min = ctx.matrix.minGradleForAgp(s.agpVersion?.value);
    if (gradle == null || min == null) return null;
    return Versions.isBelow(gradle, min) ? min : null;
  }

  /// True when Java is newer than Gradle can run on.
  static int? javaTooNewForGradle(RuleContext ctx) {
    final s = ctx.snapshot;
    final java = s.javaVersion?.value;
    final max = ctx.matrix.maxJavaForGradle(s.gradleVersion?.value);
    if (java == null || max == null) return null;
    return java > max ? max : null;
  }

  /// Components below Flutter's hard minimums: `gradle`, `agp`, `kgp`.
  static Map<String, String> belowFlutterMinimum(RuleContext ctx) {
    final r = ctx.release;
    if (r == null) return const {};
    final s = ctx.snapshot;
    final out = <String, String>{};
    void check(String key, String? actual, String? min) {
      if (actual == null || min == null) return;
      if (Versions.parse(actual) == null) return;
      if (Versions.isBelow(actual, min)) out[key] = min;
    }

    check('gradle', s.gradleVersion?.value, r.minimums.gradle);
    check('agp', s.agpVersion?.value, r.minimums.agp);
    check('kgp', s.kgpVersion?.value, r.minimums.kgp);
    return out;
  }

  /// Whether the AGP in play has Kotlin built in.
  static bool agpHasBuiltInKotlin(RuleContext ctx) {
    final agp = ctx.snapshot.agpVersion?.value;
    return agp != null && Versions.atLeast(agp, ctx.matrix.builtInKotlinFrom);
  }

  /// Whether the app module (or its settings) applies KGP.
  static bool appAppliesKgp(RuleContext ctx) =>
      ctx.snapshot.kgpApplied?.value ?? false;
}

/// GD001: Java below the minimum required by Flutter, AGP or Gradle.
class Gd001JavaTooOld extends Rule {
  /// Creates the rule.
  const Gd001JavaTooOld();

  @override
  String get id => 'GD001';

  @override
  String get description => 'Java version below the minimum required';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final java = ctx.snapshot.javaVersion;
    if (java == null) return const [];
    final min = Checks.minJava(ctx);
    if (min != null && java.value < min.java) {
      return [
        Finding(
          id: id,
          severity: Severity.error,
          message:
              'Java ${java.value} is too old: ${min.because} '
              '(found via ${ctx.snapshot.javaSource ?? 'PATH'}).',
          fix:
              'Install JDK ${min.java} (Android Studio bundles one) and tell '
              'Flutter about it: `flutter config --jdk-dir=<path-to-jdk>`. '
              'Then run `flutter doctor -v` to confirm the "Java binary at" line.',
          docs: Docs.javaGradle,
          source: java.source,
          data: {'java': java.value, 'min_java': min.java},
        ),
      ];
    }
    final warn = int.tryParse(ctx.release?.warnBelow.java ?? '');
    if (warn != null && java.value < warn) {
      return [
        Finding(
          id: id,
          severity: Severity.warning,
          message:
              'Java ${java.value} still works with ${ctx.flutterLabel}, '
              'but support for Java below $warn will be dropped.',
          fix:
              'Move to JDK $warn: `flutter config --jdk-dir=<path-to-jdk-$warn>`.',
          docs: Docs.javaGradle,
          source: java.source,
          data: {'java': java.value, 'warn_java': warn},
        ),
      ];
    }
    return const [];
  }
}

/// GD002: Gradle below the minimum required by the AGP version.
class Gd002GradleBelowAgp extends Rule {
  /// Creates the rule.
  const Gd002GradleBelowAgp();

  @override
  String get id => 'GD002';

  @override
  String get description => 'Gradle version below the minimum required by AGP';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final min = Checks.gradleBelowAgp(ctx);
    if (min == null) return const [];
    final s = ctx.snapshot;
    return [
      Finding(
        id: id,
        severity: Severity.error,
        message:
            'AGP ${s.agpVersion!.value} needs Gradle >= $min, but the '
            'wrapper uses Gradle ${s.gradleVersion!.value}.',
        fix:
            'Set distributionUrl in android/gradle/wrapper/gradle-wrapper.properties '
            'to gradle-$min-all.zip (or newer).',
        docs: Docs.agp,
        source: s.gradleVersion!.source,
        autoFixable: true,
        data: {'gradle': s.gradleVersion!.value, 'min_gradle': min},
      ),
    ];
  }
}

/// GD003: Java too new for the Gradle version.
class Gd003JavaTooNewForGradle extends Rule {
  /// Creates the rule.
  const Gd003JavaTooNewForGradle();

  @override
  String get id => 'GD003';

  @override
  String get description => 'Java too new for the Gradle version';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final max = Checks.javaTooNewForGradle(ctx);
    if (max == null) return const [];
    final s = ctx.snapshot;
    final java = s.javaVersion!.value;
    final needed = ctx.matrix.minGradleForJava(java);
    return [
      Finding(
        id: id,
        severity: Severity.error,
        message:
            'Java $java cannot run Gradle ${s.gradleVersion!.value} '
            '(it supports up to Java $max). Expect "Unsupported class file '
            'major version ${java + 44}".',
        fix: needed == null
            ? 'Upgrade Gradle, or point Flutter at JDK $max or older with '
                  '`flutter config --jdk-dir=<path>`.'
            : 'Upgrade the Gradle wrapper to $needed or newer, or point Flutter '
                  'at JDK $max or older with `flutter config --jdk-dir=<path>`.',
        docs: Docs.gradleJava,
        source: s.gradleVersion!.source,
        autoFixable: needed != null,
        data: {'java': java, 'max_java': max, 'min_gradle_for_java': needed},
      ),
    ];
  }
}

/// GD004: AGP / KGP / Gradle older than what Flutter verified.
class Gd004OlderThanVerified extends Rule {
  /// Creates the rule.
  const Gd004OlderThanVerified();

  @override
  String get id => 'GD004';

  @override
  String get description =>
      'Build tool older than the version Flutter verified';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final r = ctx.release;
    if (r == null) return const [];
    final s = ctx.snapshot;
    final belowMin = Checks.belowFlutterMinimum(ctx);
    final gradleBelowAgp = Checks.gradleBelowAgp(ctx);
    final out = <Finding>[];

    void check(
      String key,
      String label,
      Detected<String>? actual,
      String? verified,
      String where,
    ) {
      if (actual == null || verified == null) return;
      if (belowMin.containsKey(key)) return; // GD016 reports it as an error
      if (key == 'gradle' && gradleBelowAgp != null) return; // GD002
      if (Versions.parse(actual.value) == null) return;
      if (!Versions.isBelow(actual.value, verified)) return;
      out.add(
        Finding(
          id: id,
          severity: Severity.warning,
          message:
              '$label ${actual.value} is older than the $verified that '
              '${ctx.flutterLabel} was verified with.',
          fix: 'Update $label to $verified in $where.',
          docs: Docs.javaGradle,
          source: actual.source,
          autoFixable: true,
          data: {
            'component': key,
            'current': actual.value,
            'verified': verified,
          },
        ),
      );
    }

    check(
      'gradle',
      'Gradle',
      s.gradleVersion,
      r.verified.gradle,
      'android/gradle/wrapper/gradle-wrapper.properties',
    );
    check(
      'agp',
      'AGP',
      s.agpVersion,
      r.verified.agp,
      s.agpVersion?.source?.file ?? 'android/settings.gradle(.kts)',
    );
    // With built-in Kotlin the explicit KGP version stops mattering.
    if (!(s.builtInKotlin?.value ?? false) ||
        !Checks.agpHasBuiltInKotlin(ctx)) {
      check(
        'kgp',
        'Kotlin Gradle Plugin',
        s.kgpVersion,
        r.verified.kgp,
        s.kgpVersion?.source?.file ?? 'android/settings.gradle(.kts)',
      );
    }
    return out;
  }
}

/// GD005: AGP 9 + `kotlin-android` applied + built-in Kotlin not disabled.
class Gd005KgpConflictsWithBuiltInKotlin extends Rule {
  /// Creates the rule.
  const Gd005KgpConflictsWithBuiltInKotlin();

  @override
  String get id => 'GD005';

  @override
  String get description =>
      'App applies kotlin-android on AGP 9 without android.builtInKotlin=false';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    if (!Checks.agpHasBuiltInKotlin(ctx)) return const [];
    if (!Checks.appAppliesKgp(ctx)) return const [];
    final flag = s.builtInKotlin;
    if (flag != null && flag.value == false) return const [];
    final r = ctx.release;
    final legacyOk = r?.legacyKgpFlag ?? true;
    final agp = s.agpVersion!.value;
    return [
      Finding(
        id: id,
        severity: Severity.error,
        message:
            'AGP $agp has Kotlin built in, but android/app applies '
            'kotlin-android and android.builtInKotlin is '
            '${flag == null ? 'not set' : 'true'}. The build will fail with '
            '"Cannot add extension with name \'kotlin\'".',
        fix: legacyOk
            ? 'Either migrate: remove the kotlin-android plugin line and the '
                  'kotlinOptions { } block, add kotlin { compilerOptions { jvmTarget = '
                  'org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } } (see docs). '
                  'Or, until every plugin is ready, add android.builtInKotlin=false '
                  'to android/gradle.properties (`android_build_doctor fix` does this).'
            : '${ctx.flutterLabel} does not support AGP 9 at all. Stay on AGP 8.x '
                  'until you upgrade to Flutter 3.44 or newer.',
        docs: Docs.builtInKotlinApp,
        source: s.kgpApplied!.source,
        autoFixable: legacyOk,
        data: {'agp': agp, 'built_in_kotlin': flag?.value},
      ),
    ];
  }
}

/// GD006: legacy KGP on AGP 9 via `android.builtInKotlin=false`.
class Gd006LegacyKgpFlag extends Rule {
  /// Creates the rule.
  const Gd006LegacyKgpFlag();

  @override
  String get id => 'GD006';

  @override
  String get description =>
      'Legacy KGP kept alive with android.builtInKotlin=false';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    if (!Checks.agpHasBuiltInKotlin(ctx)) return const [];
    final flag = s.builtInKotlin;
    if (flag == null || flag.value) return const [];
    final r = ctx.release;
    final canEnable = r?.builtInKotlinSupported ?? false;
    final blockers = s.pluginsScanned ? s.kgpPlugins : null;
    final appApplies = Checks.appAppliesKgp(ctx);
    final String fix;
    if (!canEnable) {
      fix =
          'Nothing to do yet: ${ctx.flutterLabel} cannot enable built-in '
          'Kotlin. Plan the migration for Flutter 3.47+.';
    } else if (appApplies) {
      fix =
          'Migrate android/app/build.gradle(.kts): remove kotlin-android and '
          'kotlinOptions { }, add kotlin { compilerOptions { } }. Then run '
          '`android_build_doctor plugins` and, once every plugin is ready, set '
          'android.builtInKotlin=true.';
    } else if (blockers != null && blockers.isNotEmpty) {
      fix =
          'Your app is migrated; ${blockers.length} plugin(s) still apply KGP '
          '(${blockers.map((p) => p.name).join(', ')}). Upgrade them, then set '
          'android.builtInKotlin=true.';
    } else {
      fix =
          'Your app is migrated. Run `android_build_doctor plugins`; if every '
          'plugin is ready, set android.builtInKotlin=true in android/gradle.properties.';
    }
    final stillNeeded = appApplies || (blockers != null && blockers.isNotEmpty);
    return [
      Finding(
        id: id,
        severity: stillNeeded ? Severity.warning : Severity.info,
        message: stillNeeded
            ? 'android.builtInKotlin=false keeps the legacy Kotlin Gradle '
                  'Plugin working on AGP ${s.agpVersion!.value}. This is temporary: '
                  'Flutter will remove KGP support (flutter/flutter#184837).'
            : 'android.builtInKotlin=false is set (the Flutter template default) '
                  'but nothing here still needs the legacy Kotlin Gradle Plugin.',
        fix: fix,
        docs: Docs.builtInKotlin,
        source: flag.source,
        data: {
          'can_enable_builtin_kotlin': canEnable,
          'app_applies_kgp': appApplies,
          if (blockers != null)
            'blockers': blockers.map((p) => p.name).toList(),
        },
      ),
    ];
  }
}

/// GD007: built-in Kotlin enabled but plugins still apply KGP.
class Gd007BuiltInKotlinBlockedByPlugins extends Rule {
  /// Creates the rule.
  const Gd007BuiltInKotlinBlockedByPlugins();

  @override
  String get id => 'GD007';

  @override
  String get description =>
      'android.builtInKotlin=true but plugins still apply KGP';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    final flag = s.builtInKotlin;
    if (flag == null || !flag.value) return const [];
    if (!s.pluginsScanned) return const [];
    final blockers = s.kgpPlugins;
    if (blockers.isEmpty) return const [];
    final names = blockers.map(
      (p) => p.version == null ? p.name : '${p.name} ${p.version}',
    );
    return [
      Finding(
        id: id,
        severity: Severity.error,
        message:
            'android.builtInKotlin=true, but ${blockers.length} plugin(s) '
            'still apply the Kotlin Gradle Plugin: ${names.join(', ')}. '
            'The build will fail with "Cannot add extension with name \'kotlin\'".',
        fix:
            'Run `android_build_doctor plugins` for details. Upgrade the listed '
            'plugins (or report the issue to their authors), or set '
            'android.builtInKotlin=false until they are ready.',
        docs: Docs.builtInKotlin,
        source: flag.source,
        autoFixable: true,
        data: {'blockers': blockers.map((p) => p.name).toList()},
      ),
    ];
  }
}

/// GD008: imperative apply of Flutter's Gradle plugins.
class Gd008ImperativeApply extends Rule {
  /// Creates the rule.
  const Gd008ImperativeApply();

  @override
  String get id => 'GD008';

  @override
  String get description =>
      'Deprecated imperative apply of the Flutter Gradle plugin';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    final out = <Finding>[];
    final apply = s.flutterPluginApply;
    if (apply != null && apply.value == FlutterPluginApply.imperative) {
      out.add(
        Finding(
          id: id,
          severity: Severity.warning,
          message:
              'android/app applies Flutter\'s Gradle plugin imperatively '
              '(`apply from: flutter.gradle`). This is deprecated and will stop working.',
          fix:
              'Migrate to the declarative plugins { } block: '
              'id "dev.flutter.flutter-gradle-plugin" in android/app/build.gradle and '
              'pluginManagement { includeBuild(...) } in android/settings.gradle. '
              'Follow the linked guide (10 minutes).',
          docs: Docs.imperativeApply,
          source: apply.source,
        ),
      );
    }
    final loader = s.legacyPluginLoaderRef;
    if (loader != null) {
      out.add(
        Finding(
          id: id,
          severity: Severity.warning,
          message:
              'android/settings.gradle applies app_plugin_loader.gradle '
              'imperatively. This is deprecated.',
          fix:
              'Replace it with id "dev.flutter.flutter-plugin-loader" version "1.0.0" '
              'in a plugins { } block, as in the linked guide.',
          docs: Docs.imperativeApply,
          source: loader,
        ),
      );
    }
    return out;
  }
}

/// GD009: missing `namespace`.
class Gd009MissingNamespace extends Rule {
  /// Creates the rule.
  const Gd009MissingNamespace();

  @override
  String get id => 'GD009';

  @override
  String get description =>
      'Missing namespace in android/app/build.gradle(.kts)';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    if (s.namespace != null) return const [];
    if (s.compileSdk == null &&
        s.minSdk == null &&
        s.flutterPluginApply == null) {
      return const []; // no app build file was parsed
    }
    final agp = s.agpVersion?.value;
    final required =
        agp == null || Versions.atLeast(agp, ctx.matrix.namespaceRequiredFrom);
    final pkg = s.manifestPackage?.value;
    return [
      Finding(
        id: id,
        severity: required ? Severity.error : Severity.warning,
        message: required
            ? 'android/app/build.gradle(.kts) has no namespace. AGP '
                  '${agp ?? ctx.matrix.namespaceRequiredFrom}+ fails with "Namespace not specified".'
            : 'android/app/build.gradle(.kts) has no namespace. It will fail once '
                  'you move to AGP ${ctx.matrix.namespaceRequiredFrom}+.',
        fix: pkg == null
            ? 'Add namespace = "<your.application.id>" inside android { }.'
            : 'Add namespace = "$pkg" inside android { } (taken from '
                  'AndroidManifest.xml package). `android_build_doctor fix` can do it.',
        docs: Docs.namespace,
        source: s.compileSdk?.source ?? s.minSdk?.source,
        autoFixable: pkg != null,
        data: {'manifest_package': pkg},
      ),
    ];
  }
}

/// GD010: mismatched Java / Kotlin JVM targets.
class Gd010JvmTargetMismatch extends Rule {
  /// Creates the rule.
  const Gd010JvmTargetMismatch();

  @override
  String get id => 'GD010';

  @override
  String get description => 'sourceCompatibility and Kotlin jvmTarget differ';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    if (s.jvmToolchain != null) return const [];
    final jvm = s.jvmTarget;
    final src = s.sourceCompatibility;
    final tgt = s.targetCompatibility;
    if (jvm == null) return const [];
    final out = <Finding>[];
    for (final (label, java) in [
      ('sourceCompatibility', src),
      ('targetCompatibility', tgt),
    ]) {
      if (java == null || java.value == jvm.value) continue;
      out.add(
        Finding(
          id: id,
          severity: Severity.warning,
          message:
              '$label is Java ${java.value} but Kotlin jvmTarget is '
              '${jvm.value}. Kotlin fails with "Inconsistent JVM-target compatibility".',
          fix:
              'Set sourceCompatibility, targetCompatibility and jvmTarget to the same value '
              '(17 is what Flutter\'s template uses).',
          docs: Docs.jvmTarget,
          source: jvm.source,
          data: {label: java.value, 'jvm_target': jvm.value},
        ),
      );
    }
    return out;
  }
}

/// GD011: hard-coded SDK levels instead of `flutter.*` variables.
class Gd011HardcodedSdk extends Rule {
  /// Creates the rule.
  const Gd011HardcodedSdk();

  @override
  String get id => 'GD011';

  @override
  String get description => 'Hard-coded compileSdk/targetSdk/minSdk';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    final d = ctx.release?.defaults;
    final out = <Finding>[];
    for (final (name, det, def) in [
      ('compileSdk', s.compileSdk, d?.compileSdk),
      ('targetSdk', s.targetSdk, d?.targetSdk),
      ('minSdk', s.minSdk, d?.minSdk),
    ]) {
      if (det == null || !det.value.isLiteral) continue;
      final v = det.value.value!;
      final variable = 'flutter.${name}Version';
      final comparison = def == null
          ? ''
          : v < def
          ? ' (${ctx.flutterLabel} default is $def)'
          : v > def
          ? ' (higher than the ${ctx.flutterLabel} default $def, probably deliberate)'
          : ' (same as the ${ctx.flutterLabel} default)';
      out.add(
        Finding(
          id: id,
          severity: Severity.info,
          message: '$name is hard-coded to $v$comparison.',
          fix:
              'Use $name = $variable so it follows Flutter\'s default on upgrade, '
              'unless you need a specific value.',
          docs: Docs.gradleConfig,
          source: det.source,
          data: {'name': name, 'value': v, 'default': def},
        ),
      );
    }
    return out;
  }
}

/// GD012: minSdk below Flutter's default.
class Gd012MinSdkBelowDefault extends Rule {
  /// Creates the rule.
  const Gd012MinSdkBelowDefault();

  @override
  String get id => 'GD012';

  @override
  String get description => 'minSdk below the Flutter default';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    final def = ctx.release?.defaults.minSdk;
    final det = s.minSdk;
    if (def == null || det == null || !det.value.isLiteral) return const [];
    if (det.value.value! >= def) return const [];
    return [
      Finding(
        id: id,
        severity: Severity.warning,
        message:
            'minSdk ${det.value.value} is below ${ctx.flutterLabel}\'s '
            'default of $def. Flutter and many plugins no longer support it; '
            'expect "uses-sdk:minSdkVersion ... cannot be smaller" errors.',
        fix: 'Raise minSdk to $def (or use flutter.minSdkVersion).',
        docs: Docs.gradleConfig,
        source: det.source,
        data: {'min_sdk': det.value.value, 'default': def},
      ),
    ];
  }
}

/// GD013: `jcenter()` still present.
class Gd013Jcenter extends Rule {
  /// Creates the rule.
  const Gd013Jcenter();

  @override
  String get id => 'GD013';

  @override
  String get description => 'jcenter() repository still present';

  @override
  List<Finding> evaluate(RuleContext ctx) => [
    for (final ref in ctx.snapshot.jcenterRefs)
      Finding(
        id: id,
        severity: Severity.warning,
        message:
            'jcenter() is listed as a repository, but JCenter shut '
            'down in 2022. Dependency resolution may hang or fail.',
        fix: 'Replace jcenter() with mavenCentral().',
        docs: Docs.jcenter,
        source: ref,
        autoFixable: true,
      ),
  ];
}

/// GD014: project created with a much older Flutter.
class Gd014OldProjectTemplate extends Rule {
  /// Creates the rule.
  const Gd014OldProjectTemplate();

  /// Minor-version gap (Flutter bumps minor by 3 per stable release) above
  /// which the android folder is considered stale.
  static const int minorGap = 12;

  @override
  String get id => 'GD014';

  @override
  String get description => 'Android folder generated by a much older Flutter';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    final created = s.createdWithFlutter;
    final current = ctx.flutterVersion;
    if (created == null || current == null) return const [];
    final c = Versions.parse(created.value);
    final n = Versions.parse(current);
    if (c == null || n == null) return const [];
    final gap = (n.major - c.major) * 100 + (n.minor - c.minor);
    if (gap < minorGap) return const [];
    return [
      Finding(
        id: id,
        severity: Severity.info,
        message:
            'The android/ folder was generated by Flutter ${created.value}; '
            'you are on $current. Templates changed a lot since then '
            '(declarative plugins, Kotlin DSL, built-in Kotlin).',
        fix:
            'Consider regenerating: move android/ aside, run `flutter create .`, '
            'then copy back your applicationId, signing config, manifest changes '
            'and native code.',
        docs: Docs.upgrade,
        source: created.source,
        data: {'created_with': created.value, 'current': current},
      ),
    ];
  }
}

/// GD015: CI Java version differs from the local one.
class Gd015CiJavaMismatch extends Rule {
  /// Creates the rule.
  const Gd015CiJavaMismatch();

  @override
  String get id => 'GD015';

  @override
  String get description => 'CI java-version differs from local Java';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    final local = s.javaVersion?.value;
    if (local == null) return const [];
    return [
      for (final ci in s.ciJavaVersions)
        if (ci.value != local)
          Finding(
            id: id,
            severity: Severity.warning,
            message:
                'CI installs Java ${ci.value} but you build locally with '
                'Java $local. Builds may behave differently.',
            fix:
                'Align them: set java-version: \'$local\' in the workflow, or '
                'switch the local JDK.',
            docs: Docs.setupJava,
            source: ci.source,
            data: {'ci_java': ci.value, 'local_java': local},
          ),
    ];
  }
}

/// GD016: below Flutter's hard minimum (Flutter's Gradle plugin refuses to build).
class Gd016BelowFlutterMinimum extends Rule {
  /// Creates the rule.
  const Gd016BelowFlutterMinimum();

  @override
  String get id => 'GD016';

  @override
  String get description => 'Gradle/AGP/KGP below the minimum Flutter enforces';

  @override
  List<Finding> evaluate(RuleContext ctx) {
    final s = ctx.snapshot;
    final below = Checks.belowFlutterMinimum(ctx);
    if (below.isEmpty) return const [];
    final out = <Finding>[];
    for (final e in below.entries) {
      final (label, det, where) = switch (e.key) {
        'gradle' => (
          'Gradle',
          s.gradleVersion,
          'android/gradle/wrapper/gradle-wrapper.properties',
        ),
        'agp' => (
          'Android Gradle Plugin',
          s.agpVersion,
          s.agpVersion?.source?.file ?? 'android/settings.gradle(.kts)',
        ),
        _ => (
          'Kotlin Gradle Plugin',
          s.kgpVersion,
          s.kgpVersion?.source?.file ?? 'android/settings.gradle(.kts)',
        ),
      };
      out.add(
        Finding(
          id: id,
          severity: Severity.error,
          message:
              '${ctx.flutterLabel} refuses to build with $label ${det!.value} '
              '(minimum ${e.value}). Flutter\'s Gradle plugin stops with '
              '"is lower than Flutter\'s minimum supported version".',
          fix:
              'Update $label to at least ${e.value} in $where '
              '(`android_build_doctor fix` moves it to the verified version).',
          docs: Docs.javaGradle,
          source: det.source,
          autoFixable: true,
          data: {'component': e.key, 'current': det.value, 'minimum': e.value},
        ),
      );
    }
    return out;
  }
}
