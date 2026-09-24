import '../matrix/compat_matrix.dart';
import '../model/finding.dart';
import '../model/project_snapshot.dart';
import '../model/sdk_level.dart';
import '../model/severity.dart';
import '../model/source_ref.dart';
import 'ansi.dart';

/// Renders the `check` report for humans.
class ConsoleReporter {
  /// Creates a reporter writing through `out`.
  ConsoleReporter({required this.out, required this.ansi, this.unicode = true});

  /// Line sink (usually `stdout.writeln`).
  final void Function(String line) out;

  /// Colour helper.
  final Ansi ansi;

  /// Whether to use ✓ ⚠ ✗ symbols (ASCII fallback for `--ci`/Windows).
  final bool unicode;

  String get _ok => unicode ? '✓' : 'OK';
  String get _warn => unicode ? '⚠' : '!!';
  String get _err => unicode ? '✗' : 'XX';
  String get _info => unicode ? 'ℹ' : 'i ';
  String get _unknown => unicode ? '?' : '??';
  String get _bullet => unicode ? '•' : '*';

  String _sym(Severity? s) => switch (s) {
    null => ansi.green(_ok),
    Severity.error => ansi.red(_err),
    Severity.warning => ansi.yellow(_warn),
    Severity.info => ansi.blue(_info),
  };

  /// Prints the banner line.
  void header(String toolVersion, CompatMatrix matrix) {
    out(
      ansi.bold('android_build_doctor $toolVersion') +
          ansi.dim(' $_bullet matrix ${matrix.updated} (${matrix.source})'),
    );
  }

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
    out('');
    final fv = s.flutterVersion?.value;
    final dv = s.dartVersion?.value;
    out(
      '${ansi.bold('Project:')} ${s.projectName ?? '?'}   '
      'Flutter ${fv ?? ansi.dim('unknown')}${dv == null ? '' : ' $_bullet Dart $dv'}'
      '${s.flutterVersionSource != null && s.flutterVersionSource != 'flutter --version' ? ansi.dim('  (${s.flutterVersionSource})') : ''}',
    );
    if (targetFlutter != null) {
      out(
        '${ansi.bold('Planning upgrade to:')} Flutter $targetFlutter'
        '${release == null
            ? ansi.yellow('  (not in matrix, using nearest older release)')
            : matrix.hasExactRelease(targetFlutter)
            ? ''
            : ansi.yellow('  (using ${release.series} data)')}',
      );
    } else if (fv != null && release != null && !matrix.hasExactRelease(fv)) {
      out(
        ansi.yellow(
          'Flutter $fv is newer than the matrix (${matrix.updated}); '
          'using ${release.series} data. Run with network access or update the tool.',
        ),
      );
    }
    if (s.createdWithFlutter != null) {
      out(
        ansi.dim(
          'Created with Flutter ${s.createdWithFlutter!.value} (.metadata)',
        ),
      );
    }
    out('');

    final byComponent = _index(findings);
    _row(
      'Java',
      s.javaVersion?.value.toString(),
      byComponent['java'],
      note: s.javaVersion == null
          ? 'not found'
          : release?.minimums.java != null
          ? 'min ${release!.minimums.java}'
          : null,
      source: null,
      detail: s.javaSource,
    );
    _row(
      'Gradle',
      s.gradleVersion?.value,
      byComponent['gradle'],
      note: release?.verified.gradle == null
          ? null
          : 'verified ${release!.verified.gradle}',
      source: s.gradleVersion?.source,
    );
    _row(
      'AGP',
      s.agpVersion?.value,
      byComponent['agp'],
      note: release?.verified.agp == null
          ? null
          : 'verified ${release!.verified.agp}',
      source: s.agpVersion?.source,
    );
    final kgpNote = s.kgpVersion == null && (s.builtInKotlin?.value ?? false)
        ? 'built-in (AGP)'
        : release?.verified.kgp == null
        ? null
        : 'verified ${release!.verified.kgp}';
    _row(
      'Kotlin',
      s.kgpVersion?.value,
      byComponent['kgp'],
      note: kgpNote,
      source: s.kgpVersion?.source,
    );
    final bik = s.builtInKotlin;
    _row(
      'Built-in Kotlin',
      bik == null ? 'unset' : bik.value.toString(),
      byComponent['builtin_kotlin'],
      note: s.kgpApplied?.value == true ? 'app applies kotlin-android' : null,
      source: bik?.source ?? s.kgpApplied?.source,
    );
    _sdkRow(s, release, byComponent['sdk']);
    out('');

    final other = findings.where((f) => !_componentIds.contains(f.id)).toList();
    if (other.isNotEmpty) {
      for (final f in other) {
        _finding(f, verbose: verbose);
      }
      out('');
    }
    if (verbose) {
      for (final f in findings.where((f) => _componentIds.contains(f.id))) {
        _finding(f, verbose: true);
      }
      if (findings.any((f) => _componentIds.contains(f.id))) out('');
    }

    summary(findings);
    final fixable = findings.where((f) => f.autoFixable).length;
    if (fixable > 0) {
      out(
        'Run ${ansi.cyan('`android_build_doctor fix`')} to fix $fixable of '
        '${findings.length} automatically.',
      );
    }
    if (s.agpVersion != null ||
        findings.any(
          (f) => f.id == 'GD005' || f.id == 'GD006' || f.id == 'GD007',
        )) {
      out(
        'Run ${ansi.cyan('`android_build_doctor plugins`')} to check if your '
        'plugins are AGP 9 ready.',
      );
    }
    if (verbose && s.notes.isNotEmpty) {
      out('');
      for (final n in s.notes) {
        out(ansi.dim('note: $n'));
      }
    }
  }

  static const Set<String> _componentIds = {
    'GD001',
    'GD002',
    'GD003',
    'GD004',
    'GD005',
    'GD006',
    'GD007',
    'GD016',
  };

  Map<String, List<Finding>> _index(List<Finding> findings) {
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

  void _row(
    String label,
    String? value,
    List<Finding>? findings, {
    String? note,
    SourceRef? source,
    String? detail,
  }) {
    final worst = findings == null || findings.isEmpty
        ? null
        : (findings.toList()
                ..sort((a, b) => a.severity.rank.compareTo(b.severity.rank)))
              .first;
    final sym = value == null && worst == null
        ? ansi.dim(_unknown)
        : _sym(worst?.severity);
    final v = (value ?? '-').padRight(8);
    final msg = worst == null
        ? (note == null ? '' : ansi.dim('($note)'))
        : _short(worst);
    final loc = (worst?.source ?? source);
    final locText = worst == null || loc == null
        ? ''
        : '  ${ansi.dim(loc.toString())}';
    final detailText = detail == null || worst != null
        ? ''
        : ansi.dim('  $detail');
    out('  ${label.padRight(16)}$v $sym  $msg$locText$detailText');
  }

  void _sdkRow(
    ProjectSnapshot s,
    FlutterRelease? release,
    List<Finding>? findings,
  ) {
    String fmt(Detected<SdkLevel>? d) => d == null
        ? '-'
        : d.value.expression.replaceFirst('flutter.', 'flutter.');
    final worst = findings == null || findings.isEmpty
        ? null
        : (findings.toList()
                ..sort((a, b) => a.severity.rank.compareTo(b.severity.rank)))
              .first;
    final text =
        'compile ${fmt(s.compileSdk)}  target ${fmt(s.targetSdk)}  min ${fmt(s.minSdk)}';
    final def = release?.defaults;
    final note = def == null
        ? ''
        : ansi.dim(
            '  (defaults ${def.compileSdk}/${def.targetSdk}/${def.minSdk})',
          );
    out(
      '  ${'SDK levels'.padRight(16)}${''.padRight(8)} ${worst == null ? ansi.green(_ok) : _sym(worst.severity)}  $text$note',
    );
  }

  String _short(Finding f) {
    final m = f.message;
    final cut = m.indexOf('. ');
    final first = cut > 0 && cut < 110 ? m.substring(0, cut) : m;
    return first.length > 110 ? '${first.substring(0, 107)}...' : first;
  }

  void _finding(Finding f, {bool verbose = false}) {
    final loc = f.source == null ? '' : '  ${ansi.dim(f.source.toString())}';
    out('${_sym(f.severity)} ${ansi.bold(f.id)} ${f.message}$loc');
    if (f.fix != null) out('    ${ansi.dim('fix:')} ${f.fix}');
    if (verbose && f.docs != null) out('    ${ansi.dim('docs:')} ${f.docs}');
  }

  /// Prints the `N errors, M warnings` line.
  void summary(List<Finding> findings) {
    final e = findings.where((f) => f.severity == Severity.error).length;
    final w = findings.where((f) => f.severity == Severity.warning).length;
    final i = findings.where((f) => f.severity == Severity.info).length;
    final parts = <String>[
      if (e > 0) ansi.red('$_err $e error${e == 1 ? '' : 's'}'),
      if (w > 0) ansi.yellow('$_warn $w warning${w == 1 ? '' : 's'}'),
      if (i > 0) ansi.blue('$_info $i info'),
    ];
    out(
      parts.isEmpty ? ansi.green('$_ok No problems found.') : parts.join('  '),
    );
    out('');
  }

  /// Prints one finding in list form (used by `plugins`).
  void finding(Finding f, {bool verbose = false}) =>
      _finding(f, verbose: verbose);
}
