import 'dart:convert';
import 'dart:io';

import '../explain/explainer.dart';
import '../model/severity.dart';
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
  Future<int> run() async {
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
    out('');
    if (!result.matched) {
      out(ansi.yellow('No known pattern matched this log.'));
      if (result.whatWentWrong != null) {
        out('');
        out(ansi.bold('Gradle said:'));
        for (final l in result.whatWentWrong!.split('\n')) {
          out('  $l');
        }
      }
      if (result.culprit != null) {
        out('');
        out('Module involved: ${ansi.bold(result.culprit!.label)}');
      }
      out('');
      out(
        ansi.dim(
          'Know this error? Add a pattern to data/errors.yaml: '
          'https://github.com/zainulabdn/android_build_doctor/blob/main/data/errors.yaml',
        ),
      );
      return exitOk;
    }
    for (final e in result.explanations) {
      out(
        '${reporter.symbolFor(Severity.error)} ${ansi.bold('${e.id}  ${e.title}')}',
      );
      if (e.culprit != null) {
        out(
          '  ${ansi.dim('culprit:')} ${e.culprit!.isApp ? 'your app module' : e.culprit!.label}'
          '${e.culprit!.path != null ? ansi.dim(' (${e.culprit!.path})') : ''}',
        );
      }
      out('  ${ansi.dim('cause:')} ${e.cause}');
      for (var i = 0; i < e.fix.length; i++) {
        out('  ${ansi.dim(i == 0 ? 'fix:  ' : '      ')}${i + 1}. ${e.fix[i]}');
      }
      if (e.docs != null) {
        out('  ${ansi.dim('docs:')}  ${e.docs}');
      }
      if (verbose && e.excerpt != null) {
        out('  ${ansi.dim('log:')}   ${e.excerpt}');
      }
      out('');
    }
    return exitErrors;
  }
}
