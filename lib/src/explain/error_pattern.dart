import 'package:yaml/yaml.dart';

import '../data/bundled_data.dart';
import '../matrix/compat_matrix.dart';

/// One entry of `data/errors.yaml`.
class ErrorPattern {
  /// Creates a pattern.
  const ErrorPattern({
    required this.id,
    required this.regex,
    required this.title,
    required this.cause,
    required this.fix,
    this.docs,
    this.derive = const {},
  });

  /// Stable id such as `GE001`.
  final String id;

  /// Compiled regular expression.
  final RegExp regex;

  /// One-line title (may contain `{n}` placeholders).
  final String title;

  /// Plain-language cause (may contain placeholders).
  final String cause;

  /// Fix steps (may contain placeholders).
  final List<String> fix;

  /// Documentation link.
  final String? docs;

  /// Derived placeholders: name → (capture group, matrix map name).
  final Map<String, ({int from, String map})> derive;

  /// Parses every pattern in `yamlText` (defaults to the bundled file).
  static List<ErrorPattern> loadAll([String? yamlText]) {
    final doc = loadYaml(yamlText ?? bundledErrorsYaml);
    if (doc is! Map || doc['patterns'] is! List) return const [];
    final out = <ErrorPattern>[];
    for (final node in doc['patterns'] as List) {
      if (node is! Map) continue;
      final derive = <String, ({int from, String map})>{};
      final d = node['derive'];
      if (d is Map) {
        for (final e in d.entries) {
          final spec = e.value;
          if (spec is Map && spec['from'] is int) {
            derive[e.key.toString()] = (
              from: spec['from'] as int,
              map: spec['map']?.toString() ?? '',
            );
          }
        }
      }
      final fix = node['fix'];
      out.add(
        ErrorPattern(
          id: node['id'].toString(),
          regex: RegExp(node['regex'].toString(), multiLine: true),
          title: node['title']?.toString() ?? '',
          cause: node['cause']?.toString().trim() ?? '',
          fix: fix is List
              ? fix.map((f) => f.toString().trim()).toList()
              : fix == null
              ? const []
              : [fix.toString().trim()],
          docs: node['docs']?.toString(),
          derive: derive,
        ),
      );
    }
    return out;
  }

  /// Fills `{n}` and derived placeholders from `match`.
  String fill(String template, RegExpMatch match, CompatMatrix matrix) {
    var out = template;
    for (var i = 1; i <= match.groupCount; i++) {
      out = out.replaceAll('{$i}', match.group(i) ?? '?');
    }
    for (final e in derive.entries) {
      final raw = match.group(e.value.from);
      String value = raw ?? '?';
      if (raw != null && e.value.map == 'java_class_versions') {
        final n = int.tryParse(raw);
        if (n != null) value = matrix.javaForClassFile(n);
      }
      out = out.replaceAll('{${e.key}}', value);
    }
    return out;
  }
}
