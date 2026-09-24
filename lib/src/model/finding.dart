import 'severity.dart';
import 'source_ref.dart';

/// One diagnostic produced by a rule.
class Finding {
  /// Creates a finding.
  const Finding({
    required this.id,
    required this.severity,
    required this.message,
    this.fix,
    this.docs,
    this.source,
    this.autoFixable = false,
    this.data = const {},
  });

  /// Stable rule identifier such as `GD005` or `GP001`.
  final String id;

  /// How serious the finding is.
  final Severity severity;

  /// Plain-language description of the problem.
  final String message;

  /// Plain-language suggestion for fixing it.
  final String? fix;

  /// URL with more information.
  final String? docs;

  /// Where the offending value lives.
  final SourceRef? source;

  /// Whether `android_build_doctor fix` can repair this automatically.
  final bool autoFixable;

  /// Extra machine-readable details (for example target versions).
  final Map<String, Object?> data;

  /// JSON representation used by `--json` output.
  Map<String, Object?> toJson() => {
    'id': id,
    'severity': severity.label,
    'file': source?.file,
    'line': source?.line,
    'message': message,
    'fix': fix,
    'docs': docs,
    'auto_fixable': autoFixable,
    if (data.isNotEmpty) 'data': data,
  };

  @override
  String toString() => '$id [${severity.label}] $message';
}
