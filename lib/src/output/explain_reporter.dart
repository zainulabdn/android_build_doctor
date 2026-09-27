import '../explain/explainer.dart';
import '../model/severity.dart';
import 'ansi.dart';
import 'painter.dart';
import 'text.dart';

/// Renders the `explain` report: one block per matched pattern (culprit,
/// cause, numbered fix steps, docs) and a closing card, or the cleaned
/// "What went wrong" block when nothing matched.
class ExplainReporter {
  /// Creates a reporter that draws with `painter`.
  ExplainReporter(this.painter);

  /// The drawing primitives.
  final Painter painter;

  /// Link shown when no pattern matched.
  static const String patternsUrl =
      'https://github.com/zainulabdn/android_build_doctor/blob/main/data/errors.yaml';

  /// Prints the report.
  void report(ExplainResult result, {bool verbose = false}) {
    painter.out('');
    if (!result.matched) {
      _unmatched(result);
      return;
    }
    final p = painter, a = p.ansi, out = p.out;
    final indent = p.badgeIndent;
    String label(String name) => a.dim(name.padRight(Painter.labelWidth));
    final blank = ' ' * Painter.labelWidth;

    for (final e in result.explanations) {
      p.wrapped(
        '${p.badge(e.severity)} ${a.dim(e.id)}  ',
        e.title,
        style: a.bold,
      );
      final c = e.culprit;
      if (c != null) {
        out(
          '$indent${label('culprit')}${c.isApp ? 'your app module' : a.bold(c.label)}',
        );
        if (c.path != null) out('$indent$blank${a.dim(c.path!)}');
      }
      p.wrapped('$indent${label('cause')}', e.cause);
      for (var i = 0; i < e.fix.length; i++) {
        p.wrapped(
          '$indent${i == 0 ? label('fix') : blank}${i + 1}. ',
          e.fix[i],
        );
      }
      if (e.docs != null) out('$indent${label('docs')}${a.dim(e.docs!)}');
      if (verbose && e.excerpt != null) {
        p.wrapped('$indent${label('log')}', e.excerpt!, style: a.dim);
      }
      out('');
    }

    final n = result.explanations.length;
    final worst = result.explanations
        .map((e) => e.severity)
        .reduce((x, y) => y.rank < x.rank ? y : x);
    final culprit = result.culprit;
    p.panel([
      '${p.symbol(worst)} ${a.bold(n == 1 ? '1 known problem' : '$n known problems')} in this log'
          '${culprit == null ? '' : a.dim('  ${p.glyphs.dot}  culprit: ${culprit.isApp ? 'your app module' : culprit.label}')}',
      p.step(
        'android_build_doctor check',
        'see every version with its file and line',
      ),
      if (culprit != null && !culprit.isApp)
        p.step(
          'android_build_doctor plugins',
          'find every plugin that blocks AGP 9',
        ),
    ], border: Painter.toneFor(worst));
  }

  void _unmatched(ExplainResult result) {
    final p = painter, a = p.ansi, out = p.out;
    out(
      ' ${p.symbol(Severity.warning)} ${a.bold('No known pattern matched this log.')}',
    );
    final wrong = result.whatWentWrong;
    if (wrong != null) {
      out('');
      out('   ${a.dim('Gradle said')}');
      final rail = '   ${a.fg(Tones.warning, p.glyphs.vertical)} ';
      for (final line in wrong.split('\n')) {
        for (final part in wrapWords(line.trim(), p.width - 5)) {
          out('$rail$part');
        }
      }
    }
    final c = result.culprit;
    if (c != null) {
      out('');
      out(
        '   ${a.dim('module')}  ${c.isApp ? 'your app module' : a.bold(c.label)}',
      );
    }
    out('');
    out('   ${a.dim('Know this error? Add a pattern to data/errors.yaml:')}');
    out('   $patternsUrl');
  }
}
