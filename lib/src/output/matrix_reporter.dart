import 'dart:math' as math;

import '../matrix/compat_matrix.dart';
import '../model/severity.dart';
import 'painter.dart';
import 'text.dart';

/// Renders the `matrix` report: the Flutter releases table, the AGP and
/// Gradle requirement tables side by side, and the sources.
class MatrixReporter {
  /// Creates a reporter that draws with `painter`.
  MatrixReporter(this.painter);

  /// The drawing primitives.
  final Painter painter;

  /// Prints the report.
  void report(CompatMatrix matrix) {
    final p = painter, a = p.ansi, g = p.glyphs, out = p.out;
    out('');
    p.panel([
      a.dim(
        '${'Flutter'.padRight(9)}${'Java'.padRight(6)}${'Kotlin'.padRight(9)}'
        '${'AGP'.padRight(9)}${'Gradle'.padRight(9)}${'SDK c/t/m'.padRight(11)}'
        'Built-in Kotlin',
      ),
      for (final series in matrix.flutterSeries)
        _flutterRow(matrix.flutter[series]!),
    ], title: 'Flutter releases ${g.dot} verified versions');
    out('');

    final agp = _table(
      'AGP needs',
      [('AGP', 7), ('min Gradle', 12), ('min JDK', 0)],
      [
        for (final row in matrix.agp)
          [row.series, row.minGradle ?? '-', '${row.minJdk ?? '-'}'],
      ],
    );
    final gradle = _table(
      'Gradle runs on',
      [('Gradle', 9), ('max Java', 0)],
      [
        for (final row in matrix.gradleMaxJava) [row.gradle, '${row.java}'],
      ],
    );
    final leftWidth = visibleWidth(agp.first);
    if (leftWidth + 2 + visibleWidth(gradle.first) <= p.width) {
      for (var i = 0; i < math.max(agp.length, gradle.length); i++) {
        final left = i < agp.length ? agp[i] : ' ' * leftWidth;
        out(i < gradle.length ? '$left  ${gradle[i]}' : left);
      }
    } else {
      agp.forEach(out);
      out('');
      gradle.forEach(out);
    }

    if (matrix.sources.isNotEmpty) {
      out('');
      out(a.dim(' Sources'));
      for (final s in matrix.sources) {
        out(a.dim('   ${g.bullet} $s'));
      }
    }
  }

  String _flutterRow(FlutterRelease r) {
    final p = painter, a = p.ansi;
    final v = r.verified, d = r.defaults;
    final builtIn = r.builtInKotlinSupported
        ? '${p.symbol(null)} supported'
        : r.legacyKgpFlag
        ? '${p.symbol(Severity.warning)} false only'
        : a.dim('n/a');
    return '${a.bold(r.series.padRight(9))}${(v.java ?? '-').padRight(6)}'
        '${(v.kgp ?? '-').padRight(9)}${(v.agp ?? '-').padRight(9)}'
        '${(v.gradle ?? '-').padRight(9)}'
        '${'${d.compileSdk ?? '-'}/${d.targetSdk ?? '-'}/${d.minSdk ?? '-'}'.padRight(11)}'
        '$builtIn';
  }

  /// A small panel with a dim header row. Each column is `(title, width)`;
  /// the last column takes what it needs.
  List<String> _table(
    String title,
    List<(String, int)> columns,
    List<List<String>> rows,
  ) {
    final a = painter.ansi;
    String line(List<String> cells) => [
      for (var i = 0; i < cells.length; i++)
        i == cells.length - 1 ? cells[i] : cells[i].padRight(columns[i].$2),
    ].join();
    final body = [
      a.dim(line([for (final c in columns) c.$1])),
      for (final r in rows) line(r),
    ];
    final inner = body
        .map(visibleWidth)
        .fold(visibleWidth(title) + 2, math.max);
    return painter.panelLines(body, title: title, width: inner + 4);
  }
}
