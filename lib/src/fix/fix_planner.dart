import 'dart:io';

import 'package:path/path.dart' as p;

import '../matrix/compat_matrix.dart';
import '../model/finding.dart';
import '../model/project_snapshot.dart';
import '../model/source_ref.dart';
import '../util/versions.dart';
import 'file_edit.dart';

/// What `fix` intends to do.
class FixPlan {
  /// Creates a plan.
  const FixPlan({
    required this.edits,
    required this.advice,
    required this.rationale,
    required this.targets,
    this.temporaryKgpFlag = false,
  });

  /// File edits, in application order.
  final List<FileEdit> edits;

  /// Things the tool will not do itself (plugins, structural migrations).
  final List<String> advice;

  /// Why these targets were chosen.
  final List<String> rationale;

  /// Target versions.
  final VersionSet targets;

  /// True when the plan adds `android.builtInKotlin=false` as a stop-gap.
  final bool temporaryKgpFlag;

  /// Whether there is anything to write.
  bool get isEmpty => edits.isEmpty;

  /// Findings the edits address.
  Set<String> get findingIds => edits.map((e) => e.findingId).toSet();

  /// JSON representation.
  Map<String, Object?> toJson() => {
    'targets': targets.toJson(),
    'rationale': rationale,
    'edits': edits.map((e) => e.toJson()).toList(),
    'advice': advice,
    'temporary_kgp_flag': temporaryKgpFlag,
  };
}

/// Turns findings into minimal [FileEdit]s.
class FixPlanner {
  /// Creates a planner.
  FixPlanner({
    required this.snapshot,
    required this.matrix,
    required this.findings,
    required this.release,
  });

  /// The detected project.
  final ProjectSnapshot snapshot;

  /// The matrix.
  final CompatMatrix matrix;

  /// Findings from `check` (and `plugins`, when available).
  final List<Finding> findings;

  /// Flutter release being targeted.
  final FlutterRelease? release;

  String _abs(SourceRef ref) =>
      p.isAbsolute(ref.file) ? ref.file : p.join(snapshot.projectDir, ref.file);

  bool _has(String id) => findings.any((f) => f.id == id);

  /// Computes the plan.
  FixPlan plan() {
    final s = snapshot;
    final edits = <FileEdit>[];
    final advice = <String>[];
    final rationale = <String>[];
    final r = release;
    final pluginsKnown = s.pluginsScanned && !s.dartToolMissing;
    final blockers = pluginsKnown ? s.kgpPlugins : null;

    // ---- Choose target versions -------------------------------------------
    String? agpTarget;
    String? gradleTarget;
    String? kgpTarget;
    var temporaryFlag = false;

    if (r != null) {
      var set = r.verified;
      final verifiedAgp9 =
          r.verified.agp != null &&
          Versions.atLeast(r.verified.agp!, matrix.builtInKotlinFrom);
      final currentAgp = s.agpVersion?.value;
      final currentAgp9 =
          currentAgp != null &&
          Versions.atLeast(currentAgp, matrix.builtInKotlinFrom);
      if (verifiedAgp9 &&
          !currentAgp9 &&
          blockers != null &&
          blockers.isNotEmpty &&
          r.agp8Combo != null) {
        set = r.agp8Combo!;
        rationale.add(
          '${blockers.length} plugin(s) still apply the Kotlin Gradle '
          'Plugin (${blockers.map((b) => b.name).join(', ')}), so the plan stays '
          'on AGP ${set.agp} instead of moving you to AGP ${r.verified.agp}. '
          'Run `android_build_doctor plugins` for the full list.',
        );
      } else if (verifiedAgp9 &&
          !currentAgp9 &&
          blockers == null &&
          r.agp8Combo != null) {
        set = r.agp8Combo!;
        rationale.add(
          'Plugins could not be scanned (.dart_tool missing; run '
          '`flutter pub get`), so the plan stays on AGP ${set.agp} rather '
          'than moving to AGP ${r.verified.agp}. Re-run after `flutter pub get` '
          'to get the AGP ${r.verified.agp} plan once plugins are known.',
        );
      } else {
        rationale.add(
          'Targets are the versions Flutter ${r.series} was verified with.',
        );
      }
      agpTarget = _neverDowngrade(currentAgp, set.agp);
      kgpTarget = _neverDowngrade(s.kgpVersion?.value, set.kgp);
      gradleTarget = _neverDowngrade(s.gradleVersion?.value, set.gradle);
    } else {
      rationale.add(
        'Flutter version unknown or not in the matrix: only fixing '
        'hard requirements (Gradle vs AGP, Gradle vs Java), not bumping to '
        'verified versions.',
      );
      agpTarget = s.agpVersion?.value;
      kgpTarget = s.kgpVersion?.value;
      gradleTarget = s.gradleVersion?.value;
    }

    // Gradle must satisfy the (target) AGP and the local Java.
    final minForAgp = matrix.minGradleForAgp(agpTarget);
    if (minForAgp != null) gradleTarget = _max(gradleTarget, minForAgp);
    final java = s.javaVersion?.value;
    if (java != null) {
      final maxJava = matrix.maxJavaForGradle(gradleTarget);
      if (maxJava != null && java > maxJava) {
        final need = matrix.minGradleForJava(java);
        if (need != null) {
          gradleTarget = _max(gradleTarget, need);
          rationale.add(
            'Gradle raised to $need so it can run on your Java $java.',
          );
        }
      }
    }

    // ---- Version edits ----------------------------------------------------
    final gradleIds = ['GD002', 'GD003', 'GD016', 'GD004'].where(_has).toList();
    if (s.gradleVersion != null &&
        gradleTarget != null &&
        gradleTarget != s.gradleVersion!.value &&
        gradleIds.isNotEmpty) {
      final e = _replaceVersion(
        s.gradleVersion!,
        gradleTarget,
        'Gradle ${s.gradleVersion!.value} -> $gradleTarget',
        gradleIds.first,
      );
      if (e != null) edits.add(e);
    }
    final agpIds = ['GD016', 'GD004'].where(_has).toList();
    if (s.agpVersion != null &&
        agpTarget != null &&
        agpTarget != s.agpVersion!.value &&
        agpIds.isNotEmpty) {
      final e = _replaceVersion(
        s.agpVersion!,
        agpTarget,
        'AGP ${s.agpVersion!.value} -> $agpTarget',
        agpIds.first,
      );
      if (e != null) edits.add(e);
    }
    if (s.kgpVersion != null &&
        kgpTarget != null &&
        kgpTarget != s.kgpVersion!.value &&
        agpIds.isNotEmpty) {
      final e = _replaceVersion(
        s.kgpVersion!,
        kgpTarget,
        'Kotlin Gradle Plugin ${s.kgpVersion!.value} -> $kgpTarget',
        agpIds.first,
      );
      if (e != null) edits.add(e);
    }

    // ---- Built-in Kotlin stop-gap -----------------------------------------
    final agpAfter = agpTarget ?? s.agpVersion?.value;
    final agp9After =
        agpAfter != null &&
        Versions.atLeast(agpAfter, matrix.builtInKotlinFrom);
    final needsFlag =
        agp9After &&
        (r?.legacyKgpFlag ?? true) &&
        (_has('GD005') ||
            _has('GD007') ||
            (agp9After &&
                (s.kgpApplied?.value ?? false) &&
                s.builtInKotlin?.value != false));
    if (needsFlag) {
      final props = p.join(s.projectDir, 'android', 'gradle.properties');
      final id = _has('GD007') ? 'GD007' : 'GD005';
      final existing = s.builtInKotlin;
      if (existing != null && existing.source?.line != null) {
        edits.add(
          FileEdit.replaceLine(
            path: props,
            line: existing.source!.line!,
            newText: 'android.builtInKotlin=false',
            reason:
                'temporary: keep legacy Kotlin Gradle Plugin working on AGP 9',
            findingId: id,
          ),
        );
      } else {
        edits.add(
          FileEdit.appendLine(
            path: props,
            newText: 'android.builtInKotlin=false',
            reason:
                'temporary: keep legacy Kotlin Gradle Plugin working on AGP 9',
            findingId: id,
          ),
        );
      }
      temporaryFlag = true;
      advice.add(
        'android.builtInKotlin=false is a stop-gap. Flutter will remove '
        'support for the legacy Kotlin Gradle Plugin (flutter/flutter#184837). '
        'Migrate android/app/build.gradle(.kts) to built-in Kotlin and upgrade '
        'plugins that still apply KGP, then set the flag to true.',
      );
    }

    // ---- jcenter ------------------------------------------------------------
    for (final f in findings.where(
      (f) => f.id == 'GD013' && f.source?.line != null,
    )) {
      final path = _abs(f.source!);
      final line = _lineText(path, f.source!.line!);
      if (line == null || !line.contains('jcenter')) continue;
      if (_blockHasMavenCentral(path, f.source!.line!)) {
        edits.add(
          FileEdit.deleteLine(
            path: path,
            line: f.source!.line!,
            reason: 'JCenter shut down; mavenCentral() is already listed',
            findingId: 'GD013',
          ),
        );
      } else {
        edits.add(
          FileEdit.replaceLine(
            path: path,
            line: f.source!.line!,
            newText: line.replaceAll(
              RegExp(r'jcenter\s*\(\s*\)'),
              'mavenCentral()',
            ),
            reason: 'JCenter shut down; use Maven Central',
            findingId: 'GD013',
          ),
        );
      }
    }

    // ---- namespace ------------------------------------------------------------
    final ns = findings
        .where((f) => f.id == 'GD009' && f.autoFixable)
        .firstOrNull;
    final pkg = s.manifestPackage?.value;
    if (ns != null && pkg != null) {
      final appDir = p.join(s.projectDir, 'android', 'app');
      final kts = p.join(appDir, 'build.gradle.kts');
      final path = File(kts).existsSync()
          ? kts
          : p.join(appDir, 'build.gradle');
      final lines = _lines(path);
      if (lines != null) {
        final idx = lines.indexWhere(
          (l) => RegExp(r'^\s*android\s*\{').hasMatch(l),
        );
        if (idx >= 0) {
          final indent = _indentAfter(lines, idx);
          final decl = path.endsWith('.kts')
              ? 'namespace = "$pkg"'
              : 'namespace "$pkg"';
          edits.add(
            FileEdit.insertBefore(
              path: path,
              line: idx + 2,
              newText: '$indent$decl',
              reason:
                  'AGP 8+ requires a namespace (from AndroidManifest.xml package)',
              findingId: 'GD009',
            ),
          );
        }
      }
    }

    // ---- Advice for things we do not touch ---------------------------------
    if (blockers != null && blockers.isNotEmpty) {
      advice.add(
        'Plugins are never edited (they live in the pub cache). Blockers: '
        '${blockers.map((b) => b.version == null ? b.name : '${b.name} ${b.version}').join(', ')}. '
        'Upgrade them or open an issue with the plugin author.',
      );
    }
    if (_has('GD008')) {
      advice.add(
        'GD008 (imperative Flutter Gradle plugin apply) is a structural '
        'migration; follow https://docs.flutter.dev/release/breaking-changes/flutter-gradle-plugin-apply.',
      );
    }
    if (_has('GD010')) {
      advice.add(
        'GD010 (JVM target mismatch): set sourceCompatibility, '
        'targetCompatibility and jvmTarget to the same Java version by hand.',
      );
    }
    if (_has('GD001')) {
      advice.add(
        'GD001 (Java too old) needs a JDK install: '
        '`flutter config --jdk-dir=<path-to-jdk-17>`.',
      );
    }

    return FixPlan(
      edits: edits,
      advice: advice,
      rationale: rationale,
      targets: VersionSet(agp: agpTarget, gradle: gradleTarget, kgp: kgpTarget),
      temporaryKgpFlag: temporaryFlag,
    );
  }

  static String? _neverDowngrade(String? current, String? target) {
    if (target == null) return current;
    if (current == null || Versions.parse(current) == null) return target;
    return Versions.compare(current, target) >= 0 ? current : target;
  }

  static String? _max(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return Versions.compare(a, b) >= 0 ? a : b;
  }

  FileEdit? _replaceVersion(
    Detected<String> det,
    String target,
    String reason,
    String findingId,
  ) {
    final ref = det.source;
    if (ref == null || ref.line == null) return null;
    final path = _abs(ref);
    final line = _lineText(path, ref.line!);
    if (line == null) return null;
    final current = det.value;
    final re = RegExp(
      '(?<=["\':=\\s-])${RegExp.escape(current)}(?=["\'\\s-]|\$)',
    );
    if (!re.hasMatch(line)) return null;
    return FileEdit.replaceLine(
      path: path,
      line: ref.line!,
      newText: line.replaceFirst(re, target),
      reason: reason,
      findingId: findingId,
    );
  }

  /// True when the `repositories { }` block containing `line` already lists
  /// `mavenCentral()`.
  static bool _blockHasMavenCentral(String path, int line) {
    final lines = _lines(path);
    if (lines == null) return false;
    var start = line - 1;
    while (start > 0 && !lines[start].contains('{')) {
      start--;
    }
    var end = line - 1;
    while (end < lines.length - 1 && !lines[end].contains('}')) {
      end++;
    }
    for (var i = start; i <= end; i++) {
      if (i == line - 1) continue;
      if (RegExp(r'mavenCentral\s*\(\s*\)').hasMatch(lines[i])) return true;
    }
    return false;
  }

  static List<String>? _lines(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    return f.readAsStringSync().split(RegExp(r'\r?\n'));
  }

  static String? _lineText(String path, int line) {
    final lines = _lines(path);
    if (lines == null || line < 1 || line > lines.length) return null;
    return lines[line - 1];
  }

  static String _indentAfter(List<String> lines, int idx) {
    for (var i = idx + 1; i < lines.length; i++) {
      final l = lines[i];
      if (l.trim().isEmpty) continue;
      final m = RegExp(r'^(\s*)').firstMatch(l);
      final ind = m?.group(1) ?? '';
      if (ind.isNotEmpty) return ind;
      break;
    }
    return '    ';
  }
}
