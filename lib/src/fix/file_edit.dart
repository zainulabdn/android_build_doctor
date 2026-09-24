import 'dart:io';

/// One minimal change to one file: replace, insert or append a line.
/// Edits never rewrite whole files, so comments, quoting and indentation
/// elsewhere are untouched.
class FileEdit {
  /// Replace 1-based `line` with `newText`.
  const FileEdit.replaceLine({
    required this.path,
    required this.line,
    required this.newText,
    required this.reason,
    required this.findingId,
  }) : insert = false,
       append = false,
       delete = false;

  /// Insert `newText` before 1-based `line`.
  const FileEdit.insertBefore({
    required this.path,
    required this.line,
    required this.newText,
    required this.reason,
    required this.findingId,
  }) : insert = true,
       append = false,
       delete = false;

  /// Delete 1-based `line`.
  const FileEdit.deleteLine({
    required this.path,
    required this.line,
    required this.reason,
    required this.findingId,
  }) : newText = '',
       insert = false,
       append = false,
       delete = true;

  /// Append `newText` at the end of the file (creating it if needed).
  const FileEdit.appendLine({
    required this.path,
    required this.newText,
    required this.reason,
    required this.findingId,
  }) : line = null,
       insert = false,
       append = true,
       delete = false;

  /// Absolute path of the file.
  final String path;

  /// 1-based line for replace / insert.
  final int? line;

  /// The new line content (without newline).
  final String newText;

  /// Why (shown in the diff).
  final String reason;

  /// The finding this edit addresses.
  final String findingId;

  /// True for insert-before edits.
  final bool insert;

  /// True for append edits.
  final bool append;

  /// True for delete edits.
  final bool delete;

  /// The current text of the target line, or `null`.
  String? get currentLine {
    if (line == null) return null;
    final lines = _readLines(path);
    if (lines == null || line! < 1 || line! > lines.length) return null;
    return lines[line! - 1];
  }

  /// Applies this edit to `content` and returns the new content. The line
  /// separator (`\n` or `\r\n`) and the trailing-newline state are preserved.
  String applyTo(String content) {
    final eol = content.contains('\r\n') ? '\r\n' : '\n';
    final endsWithNewline = content.endsWith('\n');
    var lines = content.split(eol);
    if (endsWithNewline) lines = lines.sublist(0, lines.length - 1);
    if (append) {
      if (lines.isEmpty || content.isEmpty) {
        lines = [newText];
      } else {
        lines.add(newText);
      }
    } else if (insert) {
      final idx = (line! - 1).clamp(0, lines.length);
      lines.insert(idx, newText);
    } else if (delete) {
      if (line! < 1 || line! > lines.length) {
        throw StateError('$path has no line $line');
      }
      lines.removeAt(line! - 1);
    } else {
      if (line! < 1 || line! > lines.length) {
        throw StateError('$path has no line $line');
      }
      lines[line! - 1] = newText;
    }
    final joined = lines.join(eol);
    return endsWithNewline || content.isEmpty || append
        ? '$joined$eol'
        : joined;
  }

  static List<String>? _readLines(String path) {
    final f = File(path);
    if (!f.existsSync()) return null;
    return f.readAsStringSync().split(RegExp(r'\r?\n'));
  }

  /// JSON representation used by `fix --json`.
  Map<String, Object?> toJson() => {
    'path': path,
    'line': line,
    'kind': append
        ? 'append'
        : insert
        ? 'insert'
        : delete
        ? 'delete'
        : 'replace',
    'old': append || insert ? null : currentLine,
    'new': delete ? null : newText,
    'reason': reason,
    'finding': findingId,
  };
}

/// Applies a list of edits to files on disk, grouping edits per file and
/// applying them bottom-up so line numbers stay valid.
class EditApplier {
  EditApplier._();

  /// New file contents for every touched path, without writing anything.
  static Map<String, String> preview(List<FileEdit> edits) {
    final out = <String, String>{};
    for (final group in _grouped(edits).entries) {
      final f = File(group.key);
      var content = f.existsSync() ? f.readAsStringSync() : '';
      for (final e in group.value) {
        content = e.applyTo(content);
      }
      out[group.key] = content;
    }
    return out;
  }

  /// Writes `contents` (from [preview]) to disk.
  static void write(Map<String, String> contents) {
    for (final e in contents.entries) {
      File(e.key).writeAsStringSync(e.value);
    }
  }

  static Map<String, List<FileEdit>> _grouped(List<FileEdit> edits) {
    final m = <String, List<FileEdit>>{};
    for (final e in edits) {
      (m[e.path] ??= []).add(e);
    }
    for (final list in m.values) {
      // Replace edits by descending line, inserts by descending line, then appends.
      list.sort((a, b) {
        if (a.append != b.append) return a.append ? 1 : -1;
        return (b.line ?? 0).compareTo(a.line ?? 0);
      });
    }
    return m;
  }
}
