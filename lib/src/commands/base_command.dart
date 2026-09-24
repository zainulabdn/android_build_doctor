import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../detect/project_detector.dart';
import '../matrix/compat_matrix.dart';
import '../matrix/matrix_loader.dart';
import '../model/project_snapshot.dart';
import '../model/source_ref.dart';
import '../output/ansi.dart';
import '../output/console_reporter.dart';
import '../util/process.dart';

/// Exit code: OK or warnings only.
const int exitOk = 0;

/// Exit code: one or more errors found.
const int exitErrors = 1;

/// Exit code: the tool itself failed (bad input, not a Flutter project).
const int exitFailure = 2;

/// Thrown to abort a command with a message and an exit code.
class ToolExit implements Exception {
  /// Creates a tool exit.
  const ToolExit(this.message, {this.code = exitFailure});

  /// Message printed to stderr.
  final String message;

  /// Process exit code.
  final int code;

  @override
  String toString() => message;
}

/// Shared plumbing for every command: global flags, matrix loading,
/// project detection and output helpers.
abstract class BaseCommand extends Command<int> {
  /// Creates the command.
  BaseCommand();

  /// Global `--json`.
  bool get jsonOutput => globalResults?['json'] == true;

  /// Global `--ci`.
  bool get ci => globalResults?['ci'] == true;

  /// Global `--offline`.
  bool get offline => globalResults?['offline'] == true;

  /// Global `--verbose`.
  bool get verbose => globalResults?['verbose'] == true;

  /// Global `--target`.
  String? get targetFlutter => globalResults?['target'] as String?;

  /// Global `--project`.
  String get projectDir {
    final given = globalResults?['project'] as String?;
    return p.normalize(p.absolute(given ?? Directory.current.path));
  }

  /// Global `--no-color` / `--ci`.
  bool get color => !ci && globalResults?['color'] != false;

  /// Colour helper for this invocation.
  late final Ansi ansi = Ansi(enabled: color ? null : false);

  /// Console reporter for this invocation.
  late final ConsoleReporter reporter = ConsoleReporter(
    out: out,
    ansi: ansi,
    unicode: !ci && !Platform.isWindows,
  );

  /// Writes a line to stdout.
  void out(String line) => stdout.writeln(line);

  /// Writes a line to stderr.
  void err(String line) => stderr.writeln(line);

  /// Loads the matrix honouring `--offline`.
  Future<CompatMatrix> loadMatrix() async {
    final loader = MatrixLoader();
    final m = await loader.load(offline: offline);
    if (verbose) {
      for (final n in loader.notes) {
        err(ansi.dim('matrix: $n'));
      }
    }
    return m;
  }

  /// Ensures the current directory is a Flutter project with `android/`.
  /// Returns `null` (after printing a friendly note) when there is no
  /// `android/` folder, which is not an error.
  Future<ProjectSnapshot?> detectProject({bool scanPlugins = false}) async {
    final dir = projectDir;
    if (!ProjectDetector.isProject(dir)) {
      throw ToolExit(
        'No pubspec.yaml in $dir. Run this from the root of a '
        'Flutter project (or pass --project <dir>).',
      );
    }
    final runner = globalResults?['no-commands'] == true
        ? noProcess
        : defaultRunProcess;
    var snapshot = await ProjectDetector(
      run: runner,
    ).detect(dir, scanPlugins: scanPlugins);
    final assumed = globalResults?['flutter-version'] as String?;
    if (assumed != null && assumed.isNotEmpty) {
      snapshot = snapshot.copyWith(
        flutterVersion: Detected(assumed),
        flutterVersionSource: '--flutter-version',
      );
    }
    if (!snapshot.hasAndroidDir) {
      if (jsonOutput) {
        out(
          '{"tool":"android_build_doctor","has_android_dir":false,"findings":[],'
          '"summary":{"errors":0,"warnings":0,"infos":0,"exit_code":0}}',
        );
      } else {
        out(
          'No android/ folder in ${snapshot.projectName ?? dir}; nothing to check.',
        );
      }
      return null;
    }
    return snapshot;
  }
}
