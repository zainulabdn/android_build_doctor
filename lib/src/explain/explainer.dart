import '../matrix/compat_matrix.dart';
import 'error_pattern.dart';

/// A matched pattern with its placeholders filled in.
class Explanation {
  /// Creates an explanation.
  const Explanation({
    required this.id,
    required this.title,
    required this.cause,
    required this.fix,
    this.docs,
    this.excerpt,
    this.culprit,
  });

  /// Pattern id.
  final String id;

  /// Filled title.
  final String title;

  /// Filled cause.
  final String cause;

  /// Filled fix steps.
  final List<String> fix;

  /// Documentation link.
  final String? docs;

  /// The matched log text.
  final String? excerpt;

  /// Plugin or module the log blames, if any.
  final Culprit? culprit;

  /// JSON representation.
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'cause': cause,
    'fix': fix,
    'docs': docs,
    'excerpt': excerpt,
    'culprit': culprit?.toJson(),
  };
}

/// The plugin / Gradle project a failure points at.
class Culprit {
  /// Creates a culprit.
  const Culprit({
    required this.name,
    this.version,
    this.path,
    this.isApp = false,
  });

  /// Gradle project or pub package name.
  final String name;

  /// Package version when the path came from the pub cache.
  final String? version;

  /// File path from the log, if any.
  final String? path;

  /// True when the culprit is the app module itself.
  final bool isApp;

  /// Human label.
  String get label => version == null ? name : '$name $version';

  /// JSON representation.
  Map<String, Object?> toJson() => {
    'name': name,
    'version': version,
    'path': path,
    'is_app': isApp,
  };
}

/// Result of [Explainer.explain].
class ExplainResult {
  /// Creates a result.
  const ExplainResult({
    required this.explanations,
    this.culprit,
    this.whatWentWrong,
  });

  /// Matched patterns, in order of appearance in the log.
  final List<Explanation> explanations;

  /// Best guess of which module failed.
  final Culprit? culprit;

  /// The cleaned "What went wrong" block when nothing matched.
  final String? whatWentWrong;

  /// True when at least one pattern matched.
  bool get matched => explanations.isNotEmpty;

  /// JSON representation.
  Map<String, Object?> toJson() => {
    'matched': matched,
    'explanations': explanations.map((e) => e.toJson()).toList(),
    'culprit': culprit?.toJson(),
    'what_went_wrong': whatWentWrong,
  };
}

/// Matches a Gradle build log against the error patterns.
class Explainer {
  /// Creates an explainer over `patterns` (defaults to the bundled file).
  Explainer({required this.matrix, List<ErrorPattern>? patterns})
    : patterns = patterns ?? ErrorPattern.loadAll();

  /// The matrix (used for derived placeholders such as class-file → Java).
  final CompatMatrix matrix;

  /// Patterns to try.
  final List<ErrorPattern> patterns;

  static final RegExp _pubCachePath = RegExp(
    r'''[/\\]\.pub-cache[/\\](?:hosted[/\\][^/\\]+|git)[/\\]([A-Za-z0-9_]+?)(?:-([0-9][^/\\'"\s]*))?[/\\]''',
  );
  static final RegExp _rootProject = RegExp(
    r'''root project ['"]([A-Za-z0-9_]+)['"]''',
  );
  static final RegExp _gradleProject = RegExp(
    r'''project\s+['"]?:([A-Za-z0-9_]+)['"]?''',
  );
  static final RegExp _gradleTask = RegExp(
    r'''task\s+['"]:([A-Za-z0-9_]+):[A-Za-z0-9_]+['"]''',
  );
  static final RegExp _buildFile = RegExp(r'''Build file '([^']+)' line''');
  static final RegExp _whatWentWrong = RegExp(
    r'\* What went wrong:\s*\n([\s\S]*?)(?:\n\* Try:|\n\* Exception is:|\nBUILD FAILED|$)',
  );

  /// Explains `log`.
  ExplainResult explain(String log) {
    final text = _stripAnsi(log);
    final found = <(int, Explanation)>[];
    for (final p in patterns) {
      final m = p.regex.firstMatch(text);
      if (m == null) continue;
      found.add((
        m.start,
        Explanation(
          id: p.id,
          title: p.fill(p.title, m, matrix),
          cause: p.fill(p.cause, m, matrix),
          fix: [for (final f in p.fix) p.fill(f, m, matrix)],
          docs: p.docs,
          excerpt: _lineAround(text, m.start),
          culprit: _culpritNear(text, m.start),
        ),
      ));
    }
    found.sort((a, b) => a.$1.compareTo(b.$1));
    final explanations = found.map((f) => f.$2).toList();
    final culprit =
        explanations.map((e) => e.culprit).whereType<Culprit>().firstOrNull ??
        _culpritNear(text, null);
    return ExplainResult(
      explanations: explanations,
      culprit: culprit,
      whatWentWrong: explanations.isEmpty ? whatWentWrong(text) : null,
    );
  }

  /// The first "What went wrong" block, cleaned up, or `null`.
  static String? whatWentWrong(String text) {
    final m = _whatWentWrong.firstMatch(_stripAnsi(text));
    if (m == null) return null;
    final lines = m
        .group(1)!
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^\s*>\s?'), '').trimRight())
        .where((l) => l.trim().isNotEmpty)
        .toList();
    return lines.isEmpty ? null : lines.join('\n');
  }

  /// Finds the plugin/module blamed near `offset` (whole log when `null`).
  Culprit? _culpritNear(String text, int? offset) {
    final window = offset == null
        ? text
        : text.substring(
            (offset - 1500).clamp(0, text.length),
            (offset + 1500).clamp(0, text.length),
          );
    final pub = _pubCachePath.firstMatch(window);
    if (pub != null) {
      final bf = _buildFile.firstMatch(window);
      return Culprit(
        name: pub.group(1)!,
        version: pub.group(2),
        path: bf?.group(1),
      );
    }
    final names = <String>[
      for (final m in _gradleTask.allMatches(window)) m.group(1)!,
      for (final m in _gradleProject.allMatches(window)) m.group(1)!,
    ];
    if (names.isNotEmpty) {
      // Prefer a plugin over the app module: "project :app > project :plugin".
      final plugin = names.where((n) => n != 'app').firstOrNull;
      if (plugin != null) return Culprit(name: plugin);
      return const Culprit(name: 'app', isApp: true);
    }
    if (_rootProject.hasMatch(window)) {
      return const Culprit(name: 'android/ (root build script)', isApp: true);
    }
    final bf = _buildFile.firstMatch(window);
    if (bf != null) {
      final path = bf.group(1)!;
      if (path.contains('/app/') || path.contains(r'\app\')) {
        return Culprit(name: 'app', path: path, isApp: true);
      }
      return Culprit(name: path, path: path);
    }
    return null;
  }

  static String _lineAround(String text, int offset) {
    final start = text.lastIndexOf('\n', offset) + 1;
    var end = text.indexOf('\n', offset);
    if (end < 0) end = text.length;
    final line = text.substring(start, end).trim();
    return line.length > 240 ? '${line.substring(0, 240)}...' : line;
  }

  static final RegExp _ansi = RegExp(r'\x1B\[[0-9;]*[A-Za-z]');

  static String _stripAnsi(String s) => s.replaceAll(_ansi, '');
}
