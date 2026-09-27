import '../output/json_reporter.dart';
import '../output/matrix_reporter.dart';
import '../version.dart';
import 'base_command.dart';

/// `android_build_doctor matrix`.
class MatrixCommand extends BaseCommand {
  /// Creates the command.
  MatrixCommand() {
    argParser.addFlag('raw', help: 'Print the raw YAML.', negatable: false);
  }

  @override
  String get name => 'matrix';

  @override
  String get description =>
      'Print the compatibility matrix in use, its source (remote, cache or '
      'bundled) and date.';

  @override
  Future<int> execute() async {
    final matrix = await loadMatrix();
    if (argResults!['raw'] == true) {
      out(matrix.rawYaml ?? '');
      return exitOk;
    }
    if (jsonOutput) {
      out(
        JsonReporter.encode({
          'tool': 'android_build_doctor',
          'version': packageVersion,
          ...matrix.toJson(),
        }),
      );
      return exitOk;
    }
    reporter.header(packageVersion, matrix);
    MatrixReporter(painter).report(matrix);
    return exitOk;
  }
}
