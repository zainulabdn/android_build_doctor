import '../model/finding.dart';
import '../model/severity.dart';
import '../output/json_reporter.dart';
import '../rules/rules.dart';
import '../version.dart';
import 'base_command.dart';

/// `android_build_doctor check`.
class CheckCommand extends BaseCommand {
  /// Creates the command.
  CheckCommand() {
    argParser.addMultiOption(
      'ignore',
      help: 'Rule ids to skip (repeatable, or comma separated).',
      valueHelp: 'GD011,GD014',
    );
  }

  @override
  String get name => 'check';

  @override
  String get description =>
      'Read every version in the project, compare with the compatibility '
      'matrix and print a report. Changes nothing.';

  @override
  Future<int> run() async {
    final matrix = await loadMatrix();
    final snapshot = await detectProject(scanPlugins: true);
    if (snapshot == null) return exitOk;
    final ignore = (argResults!['ignore'] as List<String>).toSet();
    final ctx = RuleContext(
      snapshot: snapshot,
      matrix: matrix,
      targetFlutter: targetFlutter,
    );
    final findings = runRules(projectRules, ctx, ignore: ignore);
    final code = _exitCode(findings);

    if (jsonOutput) {
      out(
        JsonReporter.encode(
          JsonReporter.report(
            toolVersion: packageVersion,
            command: 'check',
            snapshot: snapshot,
            matrix: matrix,
            findings: findings,
            release: ctx.release,
            targetFlutter: targetFlutter,
          ),
        ),
      );
      return code;
    }
    reporter.header(packageVersion, matrix);
    reporter.report(
      snapshot: snapshot,
      matrix: matrix,
      findings: findings,
      release: ctx.release,
      targetFlutter: targetFlutter,
      verbose: verbose,
    );
    return code;
  }

  int _exitCode(List<Finding> findings) =>
      findings.any((f) => f.severity == Severity.error) ? exitErrors : exitOk;
}
