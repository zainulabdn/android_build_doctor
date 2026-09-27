import 'dart:convert';
import 'dart:io';

import '../explain/explainer.dart';
import '../output/explain_reporter.dart';
import '../output/json_reporter.dart';
import '../version.dart';
import 'base_command.dart';

/// `android_build_doctor explain <logfile | ->`.
class ExplainCommand extends BaseCommand {
  @override
  String get name => 'explain';

  @override
  String get description =>
      'Explain a failed Gradle build log in plain language. Pass a file, or '
      '`-` to read stdin: flutter build apk 2>&1 | android_build_doctor explain -';

  @override
  String get invocation => 'android_build_doctor explain <logfile | ->';

  @override
  Future<int> execute() async {
    final args = argResults!.rest;
    if (args.isEmpty) {
      throw const ToolExit('Usage: android_build_doctor explain <logfile | ->');
    }
    final String log;
    if (args.first == '-') {
      log = await stdin.transform(utf8.decoder).join();
    } else {
      final f = File(args.first);
      if (!f.existsSync()) throw ToolExit('Log file not found: ${args.first}');
      log = f.readAsStringSync();
    }
    final matrix = await loadMatrix();
    final result = Explainer(matrix: matrix).explain(log);

    if (jsonOutput) {
      out(
        JsonReporter.encode({
          'tool': 'android_build_doctor',
          'version': packageVersion,
          'command': 'explain',
          ...result.toJson(),
        }),
      );
      return result.matched ? exitErrors : exitOk;
    }

    reporter.header(packageVersion, matrix);
    ExplainReporter(painter).report(result, verbose: verbose);
    return result.matched ? exitErrors : exitOk;
  }
}
