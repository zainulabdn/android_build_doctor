import 'dart:io';

import 'package:args/command_runner.dart';

import '../version.dart';
import 'base_command.dart';
import 'check_command.dart';
import 'explain_command.dart';
import 'fix_command.dart';
import 'matrix_command.dart';
import 'plugins_command.dart';
import 'restore_command.dart';

/// The `android_build_doctor` command-line runner.
class AndroidBuildDoctorRunner extends CommandRunner<int> {
  /// Creates the runner with every command registered.
  AndroidBuildDoctorRunner()
    : super(
        'android_build_doctor',
        'Android build doctor for Flutter: checks Java/Gradle/AGP/Kotlin '
            'compatibility, audits plugins for AGP 9 readiness, explains '
            'Gradle errors and fixes what it safely can.',
      ) {
    argParser
      ..addFlag('json', help: 'Machine-readable JSON output.', negatable: false)
      ..addFlag(
        'ci',
        help: 'No prompts, no colours; exit 1 when errors are found.',
        negatable: false,
      )
      ..addFlag(
        'offline',
        help: 'Skip the remote matrix fetch and pub.dev lookups.',
        negatable: false,
      )
      ..addOption(
        'target',
        help: 'Plan an upgrade: evaluate against this Flutter version.',
        valueHelp: 'flutterVersion',
      )
      ..addOption(
        'flutter-version',
        help:
            'Assume this Flutter version instead of running `flutter --version`.',
        valueHelp: 'x.y.z',
      )
      ..addOption(
        'project',
        abbr: 'p',
        help: 'Project directory (default: current).',
        valueHelp: 'dir',
      )
      ..addFlag('verbose', abbr: 'v', help: 'More detail.', negatable: false)
      ..addFlag('color', help: 'Colour output.', defaultsTo: true)
      ..addFlag(
        'no-commands',
        help: 'Do not run flutter/java/git (faster, less accurate).',
        negatable: false,
        hide: true,
      )
      ..addFlag(
        'version',
        help: 'Print the version and exit.',
        negatable: false,
      );
    addCommand(CheckCommand());
    addCommand(PluginsCommand());
    addCommand(FixCommand());
    addCommand(ExplainCommand());
    addCommand(MatrixCommand());
    addCommand(RestoreCommand());
  }

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final results = parse(args);
      if (results['version'] == true) {
        stdout.writeln('android_build_doctor $packageVersion');
        return exitOk;
      }
      return await runCommand(results) ?? exitOk;
    } on UsageException catch (e) {
      stderr.writeln(e.message);
      stderr.writeln();
      stderr.writeln(e.usage);
      return exitFailure;
    } on ToolExit catch (e) {
      stderr.writeln('android_build_doctor: ${e.message}');
      return e.code;
    }
  }
}
