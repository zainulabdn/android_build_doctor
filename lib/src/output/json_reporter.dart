import 'dart:convert';

import '../matrix/compat_matrix.dart';
import '../model/finding.dart';
import '../model/project_snapshot.dart';
import '../model/severity.dart';

/// Builds the machine-readable report for `--json`.
class JsonReporter {
  JsonReporter._();

  /// Summary counts and exit code for a finding list.
  static Map<String, Object?> summary(List<Finding> findings) {
    final e = findings.where((f) => f.severity == Severity.error).length;
    final w = findings.where((f) => f.severity == Severity.warning).length;
    final i = findings.where((f) => f.severity == Severity.info).length;
    return {
      'errors': e,
      'warnings': w,
      'infos': i,
      'auto_fixable': findings.where((f) => f.autoFixable).length,
      'exit_code': e > 0 ? 1 : 0,
    };
  }

  /// The `check` / `plugins` report as a JSON object.
  static Map<String, Object?> report({
    required String toolVersion,
    required String command,
    required ProjectSnapshot snapshot,
    required CompatMatrix matrix,
    required List<Finding> findings,
    FlutterRelease? release,
    String? targetFlutter,
    Map<String, Object?> extra = const {},
  }) => {
    'tool': 'android_build_doctor',
    'version': toolVersion,
    'command': command,
    'matrix': {'updated': matrix.updated, 'source': matrix.source},
    'target_flutter': targetFlutter,
    'release': release?.toJson(),
    'versions': snapshot.toJson(),
    'findings': findings.map((f) => f.toJson()).toList(),
    'summary': summary(findings),
    ...extra,
  };

  /// Pretty-prints `object`.
  static String encode(Object? object) =>
      const JsonEncoder.withIndent('  ').convert(object);
}
