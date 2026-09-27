import 'dart:math' as math;

import '../fix/diff_printer.dart';
import '../fix/fix_planner.dart';
import '../model/severity.dart';
import 'ansi.dart';
import 'painter.dart';
import 'text.dart';

/// Renders the `fix` flow: the plan, a numbered diff per file, advice, and
/// the result of applying (or not applying) it.
class FixReporter {
  /// Creates a reporter that draws with `painter`.
  FixReporter(this.painter);

  /// The drawing primitives.
  final Painter painter;

  /// Prints the plan: every edit (grouped when identical) and why these
  /// targets were chosen. `files` is the number of files touched.
  void plan(FixPlan plan, {required int files}) {
    final p = painter, a = p.ansi, g = p.glyphs;
    final counts = <String, int>{};
    final order = <(String, String)>[];
    for (final e in plan.edits) {
      final key = '${e.findingId}\n${e.reason}';
      if (counts.containsKey(key)) {
        counts[key] = counts[key]! + 1;
      } else {
        counts[key] = 1;
        order.add((e.findingId, e.reason));
      }
    }
    final lines = <String>[
      for (final (id, reason) in order)
        ...p.wrapLines(
          '${a.fg(Tones.accent, g.bullet)} ${a.dim(id)}  ',
          '${reason.replaceAll(' -> ', ' ${g.arrow} ')}'
              '${counts['$id\n$reason']! > 1 ? ' (${counts['$id\n$reason']} lines)' : ''}',
          wrapWidth: p.innerWidth,
        ),
      if (plan.edits.isNotEmpty && plan.rationale.isNotEmpty) '',
      for (final r in plan.rationale)
        ...p.wrapLines(
          a.dim('${g.dot} '),
          r,
          wrapWidth: p.innerWidth,
          style: a.dim,
        ),
    ];
    p.panel(
      lines,
      title: plan.isEmpty
          ? 'Plan'
          : 'Plan ${g.dot} ${Painter.plural(plan.edits.length, 'edit')} in '
                '${Painter.plural(files, 'file')}',
    );
  }

  /// Prints the change to one file: old and new line numbers side by side,
  /// then the line, with three lines of context around each change.
  void diff(String displayPath, String before, String after) {
    final p = painter, a = p.ansi, g = p.glyphs, out = p.out;
    final hunks = DiffPrinter.hunks(before, after);
    final lines = hunks.expand((h) => h.lines);
    int digits(int? Function(DiffLine) pick) =>
        lines.map((l) => '${pick(l) ?? ''}'.length).fold(1, math.max);
    final oldDigits = digits((l) => l.oldLine);
    final newDigits = digits((l) => l.newLine);
    final rule = math.max(3, p.width - visibleWidth(displayPath) - 5);
    out('');
    out(
      ' ${a.dim(g.horizontal * 2)} ${a.bold(displayPath)} '
      '${a.dim(g.horizontal * rule)}',
    );
    for (var i = 0; i < hunks.length; i++) {
      if (i > 0) out(a.dim(' ${' ' * (oldDigits + newDigits + 1)}  ${g.gap}'));
      for (final l in hunks[i].lines) {
        final numbers =
            '${'${l.oldLine ?? ''}'.padLeft(oldDigits)} '
            '${'${l.newLine ?? ''}'.padLeft(newDigits)}';
        final body = switch (l.op) {
          '-' => a.theme(31, '-${l.text}'),
          '+' => a.theme(32, '+${l.text}'),
          _ => a.dim(' ${l.text}'),
        };
        out(' ${a.dim(numbers)}  $body');
      }
    }
  }

  /// Prints advice about what the tool does not change itself.
  void advice(List<String> advice) {
    if (advice.isEmpty) return;
    painter.out('');
    for (final text in advice) {
      painter.wrapped(' ${painter.symbol(Severity.warning)} ', text);
    }
  }

  /// Prints the closing card: what the edits fix, where the backup goes,
  /// and what to run next.
  void summary(FixPlan plan, {bool dryRun = false}) {
    final p = painter, a = p.ansi;
    p.out('');
    p.panel([
      ...p.wrapLines(
        '${p.symbol(null)} ',
        '${a.bold('Ready to fix')} ${plan.findingIds.join(', ')}',
        wrapWidth: p.innerWidth,
      ),
      ...p.wrapLines(
        '',
        'Every file is copied to android/.android_build_doctor_backup/ '
            'before it changes.',
        wrapWidth: p.innerWidth,
        style: a.dim,
      ),
      if (dryRun)
        p.step('android_build_doctor fix', 'apply these changes')
      else
        p.step('android_build_doctor restore', 'undo them later'),
    ], border: Tones.good);
  }

  /// The confirmation question (printed without a line break).
  String get prompt =>
      ' ${painter.ansi.fg(Tones.accent, '?')} Apply these changes? '
      '${painter.ansi.dim('(y/N)')} ';

  /// Prints the note for `--dry-run`.
  void dryRun() =>
      painter.out(' ${painter.ansi.dim('Dry run: nothing written.')}');

  /// Prints the note for a declined confirmation.
  void aborted() =>
      painter.out(' ${painter.ansi.dim('Aborted. Nothing written.')}');

  /// Prints the result of applying the plan.
  void applied({
    required int edits,
    required int files,
    required String backup,
    required bool temporaryKgpFlag,
  }) {
    final p = painter, a = p.ansi, out = p.out;
    String field(String name) => a.dim(name.padRight(Painter.labelWidth));
    out('');
    out(
      ' ${p.symbol(null)} ${a.bold('Applied')} '
      '${Painter.plural(edits, 'edit')} to ${Painter.plural(files, 'file')}.',
    );
    out('   ${field('backup')}$backup');
    out('   ${field('undo')}android_build_doctor restore');
    out('   ${field('verify')}flutter clean && flutter build apk --debug');
    if (temporaryKgpFlag) {
      p.wrapped(
        ' ${p.symbol(Severity.warning)} ',
        'android.builtInKotlin=false is temporary. Migrate to built-in '
            'Kotlin and remove it once your plugins are ready.',
      );
    }
  }

  /// Prints the result when there is nothing to change.
  void nothingToFix({required int remaining}) {
    final p = painter, a = p.ansi;
    p.panel([
      '${p.symbol(null)} ${a.bold('Nothing to fix automatically.')}',
      if (remaining > 0)
        a.dim(
          '${Painter.plural(remaining, 'finding')} need manual work; '
          'see android_build_doctor check.',
        ),
    ], border: remaining > 0 ? Tones.warning : Tones.good);
  }

  /// Prints the start of `--verify`.
  void verifying() {
    final a = painter.ansi;
    painter.out('');
    painter.out(
      ' ${a.fg(Tones.accent, painter.glyphs.brand)} '
      '${a.bold('Verifying:')} flutter clean && flutter build apk --debug',
    );
  }

  /// Prints the outcome of `--verify`.
  void verified(int exitCode) {
    final p = painter;
    if (exitCode == 0) {
      p.out(' ${p.symbol(null)} ${p.ansi.bold('Build succeeded.')}');
    } else {
      p.wrapped(
        ' ${p.symbol(Severity.error)} ',
        'Build failed (exit $exitCode). Pipe the log into '
            '`android_build_doctor explain -` for a diagnosis.',
      );
    }
  }
}
