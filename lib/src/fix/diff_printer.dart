import '../output/ansi.dart';

/// One line of a diff: unchanged (`' '`), removed (`'-'`) or added (`'+'`).
class DiffLine {
  /// Creates a diff line.
  const DiffLine(this.op, this.text, {this.oldLine, this.newLine});

  /// `' '`, `'-'` or `'+'`.
  final String op;

  /// The line's text, without the line break.
  final String text;

  /// 1-based line number in the old text (`null` for added lines).
  final int? oldLine;

  /// 1-based line number in the new text (`null` for removed lines).
  final int? newLine;
}

/// A run of changed lines with their surrounding context.
class DiffHunk {
  /// Creates a hunk.
  const DiffHunk({
    required this.oldStart,
    required this.oldCount,
    required this.newStart,
    required this.newCount,
    required this.lines,
  });

  /// 1-based first old line covered by the hunk.
  final int oldStart;

  /// Number of old lines in the hunk.
  final int oldCount;

  /// 1-based first new line covered by the hunk.
  final int newStart;

  /// Number of new lines in the hunk.
  final int newCount;

  /// The hunk's lines, in order.
  final List<DiffLine> lines;
}

/// Line-based diffs (LCS, 3 lines of context). Good enough for the handful
/// of single-line edits `fix` makes.
class DiffPrinter {
  /// Creates a printer.
  DiffPrinter(this.ansi);

  /// Colour helper.
  final Ansi ansi;

  /// Unified diff of `before` → `after` for `displayPath`.
  String unified(String displayPath, String before, String after) {
    final buf = StringBuffer()
      ..writeln(ansi.bold('--- a/$displayPath'))
      ..writeln(ansi.bold('+++ b/$displayPath'));
    for (final h in hunks(before, after)) {
      buf.writeln(
        ansi.cyan(
          '@@ -${h.oldStart},${h.oldCount} +${h.newStart},${h.newCount} @@',
        ),
      );
      for (final l in h.lines) {
        final line = '${l.op}${l.text}';
        buf.writeln(switch (l.op) {
          '+' => ansi.green(line),
          '-' => ansi.red(line),
          _ => line,
        });
      }
    }
    return buf.toString();
  }

  /// The hunks that turn `before` into `after`, with `context` unchanged
  /// lines around each change. Changes separated by up to twice the context
  /// share a hunk.
  static List<DiffHunk> hunks(String before, String after, {int context = 3}) {
    final ops = _diff(_lines(before), _lines(after));
    final numbered = <DiffLine>[];
    var oldLine = 0, newLine = 0;
    for (final (op, text) in ops) {
      if (op != '+') oldLine++;
      if (op != '-') newLine++;
      numbered.add(
        DiffLine(
          op,
          text,
          oldLine: op == '+' ? null : oldLine,
          newLine: op == '-' ? null : newLine,
        ),
      );
    }

    final out = <DiffHunk>[];
    var i = 0;
    while (i < ops.length) {
      if (ops[i].$1 == ' ') {
        i++;
        continue;
      }
      final start = i;
      var end = i;
      while (end < ops.length) {
        // Extend to include changes within 2 * context of each other.
        var j = end + 1;
        var gap = 0;
        while (j < ops.length && ops[j].$1 == ' ' && gap < 2 * context) {
          j++;
          gap++;
        }
        if (j < ops.length && ops[j].$1 != ' ') {
          end = j;
        } else {
          break;
        }
      }
      final hunkStart = (start - context).clamp(0, ops.length);
      final hunkEnd = (end + context + 1).clamp(0, ops.length);
      var oldBefore = 0, newBefore = 0;
      for (var k = 0; k < hunkStart; k++) {
        if (ops[k].$1 != '+') oldBefore++;
        if (ops[k].$1 != '-') newBefore++;
      }
      final lines = numbered.sublist(hunkStart, hunkEnd);
      out.add(
        DiffHunk(
          oldStart: oldBefore + 1,
          oldCount: lines.where((l) => l.op != '+').length,
          newStart: newBefore + 1,
          newCount: lines.where((l) => l.op != '-').length,
          lines: lines,
        ),
      );
      i = hunkEnd;
    }
    return out;
  }

  static List<String> _lines(String s) {
    final l = s.split('\n');
    if (l.isNotEmpty && l.last.isEmpty) l.removeLast();
    return l.map((x) => x.replaceAll('\r', '')).toList();
  }

  /// Simple LCS-based diff returning (op, text) with op in {' ', '-', '+'}.
  static List<(String, String)> _diff(List<String> a, List<String> b) {
    final n = a.length, m = b.length;
    final lcs = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        lcs[i][j] = a[i] == b[j]
            ? lcs[i + 1][j + 1] + 1
            : lcs[i + 1][j] > lcs[i][j + 1]
            ? lcs[i + 1][j]
            : lcs[i][j + 1];
      }
    }
    final out = <(String, String)>[];
    var i = 0, j = 0;
    while (i < n && j < m) {
      if (a[i] == b[j]) {
        out.add((' ', a[i]));
        i++;
        j++;
      } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
        out.add(('-', a[i]));
        i++;
      } else {
        out.add(('+', b[j]));
        j++;
      }
    }
    while (i < n) {
      out.add(('-', a[i++]));
    }
    while (j < m) {
      out.add(('+', b[j++]));
    }
    return out;
  }
}
