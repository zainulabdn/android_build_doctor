import '../output/json_reporter.dart';
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
  Future<int> run() async {
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
    out('');
    out(
      '${ansi.bold('Flutter')}   ${'Java'.padRight(6)}${'KGP'.padRight(8)}${'AGP'.padRight(8)}${'Gradle'.padRight(8)}'
      '${'SDK c/t/m'.padRight(12)}built-in Kotlin',
    );
    for (final s in matrix.flutterSeries) {
      final r = matrix.flutter[s]!;
      final v = r.verified;
      final d = r.defaults;
      final bik = r.builtInKotlinSupported
          ? 'true ok'
          : r.legacyKgpFlag
          ? 'false only'
          : 'n/a';
      out(
        '  ${s.padRight(7)} ${(v.java ?? '-').padRight(6)}${(v.kgp ?? '-').padRight(8)}'
        '${(v.agp ?? '-').padRight(8)}${(v.gradle ?? '-').padRight(8)}'
        '${'${d.compileSdk ?? '-'}/${d.targetSdk ?? '-'}/${d.minSdk ?? '-'}'.padRight(12)}$bik',
      );
    }
    out('');
    out('${ansi.bold('AGP')}      min Gradle   min JDK');
    for (final a in matrix.agp) {
      out(
        '  ${a.series.padRight(7)} ${(a.minGradle ?? '-').padRight(12)} ${a.minJdk ?? '-'}',
      );
    }
    out('');
    out('${ansi.bold('Gradle')}   max Java it runs on');
    for (final g in matrix.gradleMaxJava) {
      out('  ${g.gradle.padRight(7)} ${g.java}');
    }
    out('');
    out(ansi.dim('Sources:'));
    for (final s in matrix.sources) {
      out(ansi.dim('  $s'));
    }
    return exitOk;
  }
}
