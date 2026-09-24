/// A pointer to where a value was read from: a file and, optionally, a
/// 1-based line number.
class SourceRef {
  /// Creates a reference to [file] and an optional 1-based [line].
  const SourceRef(this.file, [this.line]);

  /// Path of the file, relative to the project root when possible.
  final String file;

  /// 1-based line number inside [file], or `null` when the value came from
  /// the whole file (or from a command rather than a file).
  final int? line;

  /// Renders as `path:line`, or just `path` when there is no line.
  @override
  String toString() => line == null ? file : '$file:$line';

  /// JSON representation used by `--json` output.
  Map<String, Object?> toJson() => {'file': file, 'line': line};

  @override
  bool operator ==(Object other) =>
      other is SourceRef && other.file == file && other.line == line;

  @override
  int get hashCode => Object.hash(file, line);
}

/// A value that was detected somewhere, together with where it was found.
class Detected<T> {
  /// Creates a detected [value] that came from [source].
  const Detected(this.value, {this.source, this.raw});

  /// The parsed value.
  final T value;

  /// Where the value was read from. `null` for values that came from running
  /// a command (for example `flutter --version`).
  final SourceRef? source;

  /// The raw text the value was parsed from, if any.
  final String? raw;

  /// JSON representation used by `--json` output.
  Map<String, Object?> toJson() => {
    'value': value,
    'file': source?.file,
    'line': source?.line,
    if (raw != null) 'raw': raw,
  };

  @override
  String toString() => '$value (${source ?? 'command'})';
}
