import 'dart:io';

/// Runs an external command. Returns `null` when the executable is missing,
/// times out, or otherwise cannot be started.
typedef RunProcess =
    Future<ProcessResult?> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

/// Default [RunProcess] backed by `Process.run` with a 60 second timeout.
Future<ProcessResult?> defaultRunProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  try {
    return await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: Platform.isWindows,
      stdoutEncoding: const SystemEncoding(),
      stderrEncoding: const SystemEncoding(),
    ).timeout(const Duration(seconds: 60));
  } on Object {
    return null;
  }
}

/// A [RunProcess] that never runs anything (for tests and `--no-commands`).
Future<ProcessResult?> noProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async => null;
