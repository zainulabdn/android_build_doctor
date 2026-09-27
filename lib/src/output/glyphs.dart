/// The symbols and box-drawing characters used in output: a Unicode set,
/// and an ASCII fallback for `--ci` and Windows consoles. Status symbols
/// and box edges are one cell wide in both sets, so layouts line up the
/// same way.
class Glyphs {
  const Glyphs._({
    required this.ok,
    required this.error,
    required this.warning,
    required this.info,
    required this.unknown,
    required this.bullet,
    required this.arrow,
    required this.brand,
    required this.dot,
    required this.ellipsis,
    required this.atLeast,
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.horizontal,
    required this.vertical,
    required this.meterFill,
    required this.meterTrack,
    required this.gap,
    required this.spinner,
  });

  /// Unicode symbols and rounded box drawing.
  static const Glyphs unicode = Glyphs._(
    ok: '✓',
    error: '✗',
    warning: '▲',
    info: '●',
    unknown: '?',
    bullet: '•',
    arrow: '→',
    brand: '◆',
    dot: '·',
    ellipsis: '…',
    atLeast: '≥',
    topLeft: '╭',
    topRight: '╮',
    bottomLeft: '╰',
    bottomRight: '╯',
    horizontal: '─',
    vertical: '│',
    meterFill: '━',
    meterTrack: '─',
    gap: '⋮',
    spinner: ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'],
  );

  /// Plain ASCII, for CI logs and consoles without Unicode.
  static const Glyphs ascii = Glyphs._(
    ok: '+',
    error: 'x',
    warning: '!',
    info: 'i',
    unknown: '?',
    bullet: '*',
    arrow: '->',
    brand: '*',
    dot: '-',
    ellipsis: '...',
    atLeast: '>=',
    topLeft: '+',
    topRight: '+',
    bottomLeft: '+',
    bottomRight: '+',
    horizontal: '-',
    vertical: '|',
    meterFill: '#',
    meterTrack: '.',
    gap: ':',
    spinner: ['-', r'\', '|', '/'],
  );

  /// No problem.
  final String ok;

  /// An error.
  final String error;

  /// A warning.
  final String warning;

  /// Information.
  final String info;

  /// A value that could not be detected.
  final String unknown;

  /// List bullet.
  final String bullet;

  /// "Leads to" / "run this next".
  final String arrow;

  /// The tool's mark in the header.
  final String brand;

  /// Separator between facts on one line.
  final String dot;

  /// Marks shortened text.
  final String ellipsis;

  /// "Greater than or equal to".
  final String atLeast;

  /// Box corner, top left.
  final String topLeft;

  /// Box corner, top right.
  final String topRight;

  /// Box corner, bottom left.
  final String bottomLeft;

  /// Box corner, bottom right.
  final String bottomRight;

  /// Box edge, horizontal.
  final String horizontal;

  /// Box edge, vertical.
  final String vertical;

  /// The filled part of a meter.
  final String meterFill;

  /// The unfilled track of a meter.
  final String meterTrack;

  /// Marks skipped lines between diff hunks.
  final String gap;

  /// Spinner animation frames.
  final List<String> spinner;
}
