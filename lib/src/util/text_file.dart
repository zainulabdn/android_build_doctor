import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/source_ref.dart';

/// A text file split into lines, with helpers for line-oriented regex
/// searches that report 1-based line numbers.
class TextFile {
  /// Wraps already-read content.
  TextFile(this.path, this.content, {String? displayPath})
    : lines = content.split('\n'),
      displayPath = displayPath ?? path;

  /// Reads `path` if it exists, otherwise returns `null`.
  static TextFile? read(String path, {String? relativeTo}) {
    final f = File(path);
    if (!f.existsSync()) return null;
    String content;
    try {
      content = f.readAsStringSync();
    } on FileSystemException {
      return null;
    }
    final display = relativeTo == null
        ? path
        : p.relative(path, from: relativeTo);
    return TextFile(path, content, displayPath: display);
  }

  /// Absolute path on disk.
  final String path;

  /// Path used in reports (usually relative to the project root).
  final String displayPath;

  /// Whole content.
  final String content;

  /// Content split on `\n` (a trailing `\r` is left in place so that
  /// re-joining yields the original bytes).
  final List<String> lines;

  /// True when the file is a Kotlin DSL build script.
  bool get isKts => path.endsWith('.kts');

  /// Whether the line at `index` (0-based) is a comment or blank.
  bool isCommentLine(int index) {
    final t = lines[index].trimLeft();
    return t.isEmpty ||
        t.startsWith('//') ||
        t.startsWith('#') ||
        t.startsWith('*') ||
        t.startsWith('/*');
  }

  /// The first line matching `pattern`, ignoring comment lines.
  LineMatch? firstMatch(RegExp pattern) {
    for (var i = 0; i < lines.length; i++) {
      if (isCommentLine(i)) continue;
      final m = pattern.firstMatch(lines[i]);
      if (m != null) return LineMatch(this, i + 1, m);
    }
    return null;
  }

  /// All lines matching `pattern`, ignoring comment lines.
  List<LineMatch> allMatches(RegExp pattern) {
    final out = <LineMatch>[];
    for (var i = 0; i < lines.length; i++) {
      if (isCommentLine(i)) continue;
      final m = pattern.firstMatch(lines[i]);
      if (m != null) out.add(LineMatch(this, i + 1, m));
    }
    return out;
  }

  /// A [SourceRef] for a 1-based line number.
  SourceRef ref(int line) => SourceRef(displayPath, line);
}

/// A regex match on a specific line of a [TextFile].
class LineMatch {
  /// Creates a match.
  LineMatch(this.file, this.line, this.match);

  /// The file searched.
  final TextFile file;

  /// 1-based line number.
  final int line;

  /// The regex match.
  final RegExpMatch match;

  /// Capture group `n`, trimmed.
  String? group(int n) => match.group(n)?.trim();

  /// First non-null capture group among `groups`.
  String? firstGroup(List<int> groups) {
    for (final g in groups) {
      final v = match.group(g);
      if (v != null) return v.trim();
    }
    return null;
  }

  /// The source reference for this line.
  SourceRef get ref => file.ref(line);

  /// Full text of the line.
  String get text => file.lines[line - 1];
}
