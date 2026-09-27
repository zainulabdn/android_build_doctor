import '../matrix/compat_matrix.dart';
import '../model/finding.dart';
import '../model/project_snapshot.dart';
import '../model/sdk_level.dart';
import '../model/severity.dart';
import '../model/source_ref.dart';
import '../util/versions.dart';
import 'ansi.dart';
import 'glyphs.dart';
import 'painter.dart';
import 'text.dart';

/// Renders the `check` report: a toolchain panel with one row per
/// component, every finding with its location and fix, and a closing card
/// with the counts and what to run next.
class ConsoleReporter {
  /// Creates a reporter writing through `out`.
  ConsoleReporter({
    required void Function(String line) out,
    required Ansi ansi,
    bool unicode = true,
    int width = 80,
  }) : painter = Painter(
         out: out,
         ansi: ansi,
         glyphs: unicode ? Glyphs.unicode : Glyphs.ascii,
         width: width,
       );

  /// Creates a reporter that draws with `painter`.
  ConsoleReporter.withPainter(this.painter);

  /// The drawing primitives.
  final Painter painter;

  Ansi get _a => painter.ansi;
  Glyphs get _g => painter.glyphs;
  void _out(String line) => painter.out(line);

  /// Symbol for a severity; `null` means "no problem". Honours the ASCII
  /// fallback used by `--ci` and Windows.
  String symbolFor(Severity? s) => painter.symbol(s);

  /// Prints the banner line.
  void header(String toolVersion, CompatMatrix matrix) =>
      painter.header(toolVersion, matrix);

  /// Prints the full `check` report.
  void report({
    required ProjectSnapshot snapshot,
    required CompatMatrix matrix,
    required List<Finding> findings,
    required FlutterRelease? release,
    String? targetFlutter,
    bool verbose = false,
  }) {
    final s = snapshot;
    _out('');
    _projectLines(s, matrix, release, targetFlutter);
    _out('');
    painter.panel(
      _toolchainRows(s, matrix, release, findings),
      title: 'Toolchain',
    );
    _out('');
    for (final f in findings) {
      painter.finding(f, verbose: verbose);
      _out('');
    }
    painter.panel(
      _closingLines(s, findings, release),
      border: Painter.toneFor(Painter.worstOf(findings)),
    );
    if (verbose && s.notes.isNotEmpty) {
      _out('');
      for (final n in s.notes) {
        painter.wrapped(_a.dim(' note  '), n, style: _a.dim);
      }
    }
  }

  /// Prints the `N errors  M warnings` line (or "No problems found").
  void summary(List<Finding> findings) {
    _out(
      ' ${painter.counts(findings) ?? '${painter.symbol(null)} No problems found.'}',
    );
    _out('');
  }

  /// Prints one finding in list form.
  void finding(Finding f, {bool verbose = false}) =>
      painter.finding(f, verbose: verbose);

  void _projectLines(
    ProjectSnapshot s,
    CompatMatrix matrix,
    FlutterRelease? release,
    String? targetFlutter,
  ) {
    final a = _a, g = _g;
    final fv = s.flutterVersion?.value;
    final dv = s.dartVersion?.value;
    final source =
        s.flutterVersionSource != null &&
            s.flutterVersionSource != 'flutter --version'
        ? a.dim('  (${s.flutterVersionSource})')
        : '';
    _out(
      ' ${a.bold(s.projectName ?? '?')}  '
      'Flutter ${fv ?? a.dim('unknown')}'
      '${dv == null ? '' : ' ${a.dim(g.dot)} Dart $dv'}$source',
    );
    if (targetFlutter != null) {
      final note = release == null
          ? 'not in the matrix'
          : matrix.hasExactRelease(targetFlutter)
          ? null
          : 'using ${release.series} data';
      _out(
        ' ${a.fg(Tones.accent, g.arrow)} Planning an upgrade to '
        '${a.bold('Flutter $targetFlutter')}'
        '${note == null ? '' : a.dim('  ($note)')}',
      );
    } else if (fv != null && release != null && !matrix.hasExactRelease(fv)) {
      painter.wrapped(
        ' ${painter.symbol(Severity.warning)} ',
        'Flutter $fv is newer than the matrix (${matrix.updated}); using '
            '${release.series} data. Run with network access or update the tool.',
      );
    }
    if (s.createdWithFlutter != null) {
      _out(
        a.dim(
          ' Created with Flutter ${s.createdWithFlutter!.value} (.metadata)',
        ),
      );
    }
  }

  List<String> _toolchainRows(
    ProjectSnapshot s,
    CompatMatrix matrix,
    FlutterRelease? r,
    List<Finding> findings,
  ) {
    final by = _byComponent(findings);
    final g = _g;
    final builtIn = s.kgpVersion == null && (s.builtInKotlin?.value ?? false);
    return [
      _row(
        s,
        'Java',
        s.javaVersion?.value.toString(),
        by['java'],
        ok: [
          if (r?.minimums.java != null) 'min ${r!.minimums.java}',
          if (s.javaSource != null) s.javaSource!,
        ].join(' ${g.dot} '),
      ),
      _row(
        s,
        'Gradle',
        s.gradleVersion?.value,
        by['gradle'],
        ok: _verified(r?.verified.gradle),
      ),
      _row(
        s,
        'AGP',
        s.agpVersion?.value,
        by['agp'],
        ok: _verified(r?.verified.agp),
      ),
      _row(
        s,
        'Kotlin',
        builtIn ? 'built-in' : s.kgpVersion?.value,
        by['kgp'],
        ok: builtIn ? 'provided by AGP' : _verified(r?.verified.kgp),
      ),
      _row(
        s,
        'Built-in Kotlin',
        s.builtInKotlin == null ? 'unset' : '${s.builtInKotlin!.value}',
        by['builtin_kotlin'],
        ok: _builtInNote(s, matrix),
      ),
      _row(s, 'SDK levels', _sdkValue(s, r), by['sdk'], ok: _sdkNote(s)),
    ];
  }

  String _row(
    ProjectSnapshot s,
    String label,
    String? value,
    List<Finding>? findings, {
    required String ok,
  }) {
    final a = _a;
    final worst = findings == null || findings.isEmpty
        ? null
        : findings.reduce((x, y) => y.severity.rank < x.severity.rank ? y : x);
    final sym = value == null && worst == null
        ? a.dim(_g.unknown)
        : painter.symbol(worst?.severity);
    final shown = truncateVisible(value ?? '-', 9, ellipsis: _g.ellipsis);
    final String note;
    if (worst != null) {
      final more = findings!.length > 1
          ? a.dim('  +${findings.length - 1} more')
          : '';
      note = '${_note(worst, s)}$more';
    } else {
      note = a.dim(value == null ? 'not found' : ok);
    }
    return '$sym ${label.padRight(17)}${padVisible(shown, 10)}$note';
  }

  String _verified(String? v) => v == null ? '' : 'verified $v';

  String _builtInNote(ProjectSnapshot s, CompatMatrix matrix) {
    final agp = s.agpVersion?.value;
    final agp9 = agp != null && Versions.atLeast(agp, matrix.builtInKotlinFrom);
    if (!agp9) return 'applies from AGP ${matrix.builtInKotlinFrom}';
    if (s.builtInKotlin?.value ?? false) return 'Kotlin comes with AGP';
    return 'AGP default';
  }

  static const Map<String, String> _flutterVariables = {
    'compile': 'flutter.compileSdkVersion',
    'target': 'flutter.targetSdkVersion',
    'min': 'flutter.minSdkVersion',
  };

  String? _sdkValue(ProjectSnapshot s, FlutterRelease? r) {
    final levels = <String, (Detected<SdkLevel>?, int?)>{
      'compile': (s.compileSdk, r?.defaults.compileSdk),
      'target': (s.targetSdk, r?.defaults.targetSdk),
      'min': (s.minSdk, r?.defaults.minSdk),
    };
    if (levels.values.every((l) => l.$1 == null)) return null;
    String one(String key) {
      final (d, def) = levels[key]!;
      if (d == null) return '-';
      final v = d.value;
      if (v.value != null) return '${v.value}';
      if (v.expression == _flutterVariables[key]) return def?.toString() ?? '?';
      return '*';
    }

    final parts = [for (final k in levels.keys) one(k)];
    if (parts.every((p) => p == '?')) return 'flutter';
    return parts.join('/');
  }

  String _sdkNote(ProjectSnapshot s) {
    final allDefault = [
      (s.compileSdk, 'compile'),
      (s.targetSdk, 'target'),
      (s.minSdk, 'min'),
    ].every((e) => e.$1?.value.expression == _flutterVariables[e.$2]);
    return allDefault ? 'Flutter defaults' : 'compile / target / min';
  }

  String _note(Finding f, ProjectSnapshot s) {
    final d = f.data;
    final ge = _g.atLeast;
    return switch (f.id) {
      'GD001' when f.severity == Severity.error =>
        'needs Java $ge ${d['min_java']}',
      'GD001' => 'Java ${d['warn_java']} recommended',
      'GD002' => 'needs $ge ${d['min_gradle']} for AGP ${s.agpVersion?.value}',
      'GD003' => 'cannot run on Java ${d['java']} (max ${d['max_java']})',
      'GD004' => 'older than verified ${d['verified']}',
      'GD016' => 'below Flutter minimum ${d['minimum']}',
      'GD005' => 'app applies kotlin-android',
      'GD006' when f.severity == Severity.info =>
        'legacy mode no longer needed',
      'GD006' => 'legacy Kotlin plugin (temporary)',
      'GD007' =>
        '${Painter.plural((d['blockers'] as List?)?.length ?? 0, 'plugin')} '
            'still apply KGP',
      'GD011' => 'hard-coded ${d['name']} ${d['value']}',
      'GD012' => 'minSdk ${d['min_sdk']} is below ${d['default']}',
      _ => _firstSentence(f.message),
    };
  }

  static String _firstSentence(String message) {
    final cut = message.indexOf('. ');
    return cut > 0 ? message.substring(0, cut) : message;
  }

  Map<String, List<Finding>> _byComponent(List<Finding> findings) {
    final m = <String, List<Finding>>{};
    void add(String k, Finding f) => (m[k] ??= []).add(f);
    for (final f in findings) {
      switch (f.id) {
        case 'GD001':
          add('java', f);
        case 'GD002' || 'GD003':
          add('gradle', f);
        case 'GD004' || 'GD016':
          add(f.data['component']?.toString() ?? 'gradle', f);
        case 'GD005' || 'GD006' || 'GD007':
          add('builtin_kotlin', f);
        case 'GD011' || 'GD012':
          add('sdk', f);
      }
    }
    return m;
  }

  List<String> _closingLines(
    ProjectSnapshot s,
    List<Finding> findings,
    FlutterRelease? release,
  ) {
    final a = _a;
    final fixable = findings.where((f) => f.autoFixable).length;
    final counts = painter.counts(findings);
    return [
      if (counts == null)
        '${painter.symbol(null)} ${a.bold('No problems found.')}'
            '${release == null ? '' : a.dim('  Everything matches Flutter ${release.series}.')}'
      else
        '$counts${fixable > 0 ? a.dim('  ${_g.dot}  $fixable fixable automatically') : ''}',
      if (fixable > 0)
        painter.step(
          'android_build_doctor fix',
          'preview the diff, then apply',
        ),
      if (s.agpVersion != null ||
          findings.any(
            (f) => f.id == 'GD005' || f.id == 'GD006' || f.id == 'GD007',
          ))
        painter.step('android_build_doctor plugins', 'check AGP 9 readiness'),
    ];
  }
}
