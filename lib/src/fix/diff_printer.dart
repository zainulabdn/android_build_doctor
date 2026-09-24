import '../output/ansi.dart';

/// Produces a unified diff between two texts (line-based, 3 lines of
/// context). Good enough for the handful of single-line edits `fix` makes.
class DiffPrinter {
  /// Creates a printer.
  DiffPrinter(this.ansi);

  /// Colour helper.
  final Ansi ansi;

  /// Unified diff of `before` → `after` for `displayPath`.
  String unified(String displayPath, String before, String after) {
    final a = _lines(before);
    final b = _lines(after);
    final ops = _diff(a, b);
    final buf = StringBuffer()
      ..writeln(ansi.bold('--- a/$displayPath'))
      ..writeln(ansi.bold('+++ b/$displayPath'));

    // Group changes into hunks with 3 lines of context.
    const ctx = 3;
    var i = 0;
    while (i < ops.length) {
      if (ops[i].$1 == ' ') {
        i++;
        continue;
      }
      var start = i;
      var end = i;
      while (end < ops.length) {
        // extend to include changes within 2*ctx of each other
        var j = end + 1;
        var gap = 0;
        while (j < ops.length && ops[j].$1 == ' ' && gap < 2 * ctx) {
          j++;
          gap++;
        }
        if (j < ops.length && ops[j].$1 != ' ') {
          end = j;
        } else {
          break;
        }
      }
      // find last change index within [start, end]
      var lastChange = end;
      while (lastChange > start && ops[lastChange].$1 == ' ') {
        lastChange--;
      }
      final hunkStart = (start - ctx).clamp(0, ops.length);
      final hunkEnd = (lastChange + ctx + 1).clamp(0, ops.length);
      var aLine = 0, bLine = 0;
      for (var k = 0; k < hunkStart; k++) {
        if (ops[k].$1 != '+') aLine++;
        if (ops[k].$1 != '-') bLine++;
      }
      var aCount = 0, bCount = 0;
      for (var k = hunkStart; k < hunkEnd; k++) {
        if (ops[k].$1 != '+') aCount++;
        if (ops[k].$1 != '-') bCount++;
      }
      buf.writeln(
        ansi.cyan('@@ -${aLine + 1},$aCount +${bLine + 1},$bCount @@'),
      );
      for (var k = hunkStart; k < hunkEnd; k++) {
        final (op, text) = ops[k];
        final line = '$op$text';
        buf.writeln(switch (op) {
          '+' => ansi.green(line),
          '-' => ansi.red(line),
          _ => line,
        });
      }
      i = hunkEnd;
    }
    return buf.toString();
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
