import 'dart:math' as math;

import '../matrix/compat_matrix.dart';
import '../model/finding.dart';
import '../model/severity.dart';
import 'ansi.dart';
import 'glyphs.dart';
import 'text.dart';

/// Draws the pieces every report is built from: the header line, rounded
/// panels, severity badges, meters, finding blocks and next-step rows.
class Painter {
  /// Creates a painter writing lines through `out`, at most `width` cells
  /// wide.
  Painter({
    required this.out,
    required this.ansi,
    this.glyphs = Glyphs.unicode,
    this.width = 80,
  });

  /// Line sink (usually `stdout.writeln`).
  final void Function(String line) out;

  /// Colour helper.
  final Ansi ansi;

  /// Symbol set.
  final Glyphs glyphs;

  /// Layout width in terminal cells.
  final int width;

  /// Width of a severity badge such as ` ERROR `.
  static const int badgeWidth = 7;

  /// Width of a field label such as `culprit` plus its gap.
  static const int labelWidth = 9;

  /// Indent that lines continuation text up under the text after a badge.
  String get badgeIndent => ' ' * (badgeWidth + 1);

  /// Cells available inside a panel of the full width.
  int get innerWidth => width - 4;

  /// The tone for a severity; `null` means "no problem".
  static Tone toneFor(Severity? severity) => switch (severity) {
    null => Tones.good,
    Severity.error => Tones.error,
    Severity.warning => Tones.warning,
    Severity.info => Tones.accent,
  };

  /// The worst severity in `findings`, or `null` when there are none.
  static Severity? worstOf(Iterable<Finding> findings) {
    Severity? worst;
    for (final f in findings) {
      if (worst == null || f.severity.rank < worst.rank) worst = f.severity;
    }
    return worst;
  }

  /// The coloured symbol for a severity; `null` means "no problem".
  String symbol(Severity? severity) =>
      ansi.fg(toneFor(severity), switch (severity) {
        null => glyphs.ok,
        Severity.error => glyphs.error,
        Severity.warning => glyphs.warning,
        Severity.info => glyphs.info,
      });

  /// A solid label block, [badgeWidth] cells wide: ` ERROR `, `  WARN `,
  /// `  INFO `.
  String badge(Severity severity) {
    final (label, fill, ink) = switch (severity) {
      Severity.error => ('ERROR', Tones.errorFill, Tones.white),
      Severity.warning => ('WARN', Tones.warningFill, Tones.ink),
      Severity.info => ('INFO', Tones.infoFill, Tones.white),
    };
    return ansi.badge(' ${label.padLeft(badgeWidth - 2)} ', fill, ink);
  }

  /// The first line of every report: the tool, its version and the matrix
  /// in use.
  void header(String toolVersion, CompatMatrix matrix) {
    out(
      ' ${ansi.fg(Tones.accent, glyphs.brand)} '
      '${ansi.bold('android_build_doctor')}  '
      '${ansi.dim('v$toolVersion ${glyphs.dot} matrix ${matrix.updated} (${matrix.source})')}',
    );
  }

  /// `lead` followed by `text` word-wrapped to `wrapWidth` (the full width
  /// by default), continuation lines indented to line up under the text.
  /// Words longer than a line (URLs, paths) are kept whole.
  List<String> wrapLines(
    String lead,
    String text, {
    int? wrapWidth,
    String Function(String)? style,
  }) {
    final indent = visibleWidth(lead);
    final room = math.max(12, (wrapWidth ?? width) - indent);
    final paint = style ?? (String s) => s;
    final lines = wrapWords(text, room, breakWords: false);
    return [
      '$lead${paint(lines.first)}',
      for (final l in lines.skip(1)) '${' ' * indent}${paint(l)}',
    ];
  }

  /// Prints [wrapLines].
  void wrapped(String lead, String text, {String Function(String)? style}) {
    wrapLines(lead, text, style: style).forEach(out);
  }

  /// A rounded panel around `lines`, `width` cells wide (the full width by
  /// default). Lines that do not fit are shortened with an ellipsis; wrap
  /// them first with [wrapLines] and [innerWidth] to keep every word. The
  /// border is dim unless a `border` tone is given.
  List<String> panelLines(
    List<String> lines, {
    String? title,
    Tone? border,
    int? width,
  }) {
    final w = width ?? this.width;
    final inner = w - 4;
    final g = glyphs;
    String edge(String s) => border == null ? ansi.dim(s) : ansi.fg(border, s);
    final String top;
    if (title == null) {
      top = edge('${g.topLeft}${g.horizontal * (w - 2)}${g.topRight}');
    } else {
      final t = truncateVisible(title, w - 6, ellipsis: g.ellipsis);
      top =
          '${edge('${g.topLeft}${g.horizontal} ')}${ansi.bold(t)}'
          '${edge(' ${g.horizontal * (w - 5 - visibleWidth(t))}${g.topRight}')}';
    }
    return [
      top,
      for (final l in lines)
        '${edge(g.vertical)} '
            '${padVisible(truncateVisible(l, inner, ellipsis: g.ellipsis), inner)}'
            ' ${edge(g.vertical)}',
      edge('${g.bottomLeft}${g.horizontal * (w - 2)}${g.bottomRight}'),
    ];
  }

  /// Prints [panelLines].
  void panel(List<String> lines, {String? title, Tone? border, int? width}) {
    panelLines(lines, title: title, border: border, width: width).forEach(out);
  }

  /// A meter `cells` wide showing `value` of `total`: the filled part in
  /// `tone`, the rest a faint track of the same tone drawn with a thinner
  /// glyph, so the two read apart even without colour. The bar is only full
  /// when everything is done and only empty when nothing is.
  String meter(int value, int total, int cells, Tone tone) {
    if (cells < 1) return '';
    var filled = total <= 0 ? 0 : (value * cells / total).round();
    if (value < total && filled >= cells) filled = cells - 1;
    if (value > 0 && filled <= 0) filled = 1;
    filled = filled.clamp(0, cells);
    return ansi.fg(tone, glyphs.meterFill * filled) +
        ansi.dim(ansi.fg(tone, glyphs.meterTrack * (cells - filled)));
  }

  /// `✗ 2 errors  ▲ 1 warning  ● 3 info`, or `null` when `findings` is
  /// empty. The symbols carry the colour; the words stay in the text
  /// colour.
  String? counts(List<Finding> findings) {
    int n(Severity s) => findings.where((f) => f.severity == s).length;
    final e = n(Severity.error), w = n(Severity.warning), i = n(Severity.info);
    final parts = [
      if (e > 0) '${symbol(Severity.error)} ${plural(e, 'error')}',
      if (w > 0) '${symbol(Severity.warning)} ${plural(w, 'warning')}',
      if (i > 0) '${symbol(Severity.info)} $i info',
    ];
    return parts.isEmpty ? null : parts.join('  ');
  }

  /// A next-step row: `→ command   what it does`.
  String step(String command, String description, {int commandWidth = 30}) {
    final pad = math.max(commandWidth, command.length + 2);
    return '${ansi.fg(Tones.accent, glyphs.arrow)} '
        '${ansi.bold(command)}${' ' * (pad - command.length)}'
        '${ansi.dim(description)}';
  }

  /// Prints a finding: badge, id and message, then where it was found, the
  /// fix, and (verbose) the docs link.
  void finding(Finding f, {bool verbose = false}) {
    final indent = badgeIndent;
    wrapped('${badge(f.severity)} ${ansi.dim(f.id)}  ', f.message);
    if (f.source != null) out('$indent${ansi.dim(f.source.toString())}');
    if (f.fix != null) wrapped('$indent${ansi.dim('fix')}  ', f.fix!);
    if (verbose && f.docs != null) {
      out('$indent${ansi.dim('docs')} ${ansi.dim(f.docs!)}');
    }
  }

  /// `1 plugin`, `3 plugins`.
  static String plural(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
}
