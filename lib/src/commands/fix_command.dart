import 'dart:io';

import '../fix/backup_manager.dart';
import '../fix/diff_printer.dart';
import '../fix/file_edit.dart';
import '../fix/fix_planner.dart';
import '../model/severity.dart';
import '../output/ansi.dart';
import '../output/fix_reporter.dart';
import '../output/json_reporter.dart';
import '../rules/rules.dart';
import '../util/paths.dart';
import '../util/process.dart';
import '../version.dart';
import 'base_command.dart';

/// `android_build_doctor fix`.
class FixCommand extends BaseCommand {
  /// Creates the command.
  FixCommand() {
    argParser
      ..addFlag(
        'dry-run',
        help: 'Show the diff and write nothing.',
        negatable: false,
      )
      ..addFlag(
        'yes',
        abbr: 'y',
        help: 'Apply without asking.',
        negatable: false,
      )
      ..addFlag(
        'verify',
        help:
            'After applying, run `flutter clean && flutter build apk --debug`.',
        negatable: false,
      )
      ..addMultiOption('ignore', help: 'Rule ids to skip.', valueHelp: 'GD013');
  }

  @override
  String get name => 'fix';

  @override
  String get description =>
      'Apply safe fixes: version bumps, jcenter() -> mavenCentral(), missing '
      'namespace, temporary android.builtInKotlin=false. Shows a diff, asks '
      'for confirmation and backs files up first.';

  @override
  Future<int> execute() async {
    final dryRun = argResults!['dry-run'] == true;
    final yes = argResults!['yes'] == true || ci;
    final verify = argResults!['verify'] == true;
    final matrix = await loadMatrix();
    final snapshot = await detectProject(scanPlugins: true);
    if (snapshot == null) return exitOk;
    final ignore = (argResults!['ignore'] as List<String>).toSet();
    final ctx = RuleContext(
      snapshot: snapshot,
      matrix: matrix,
      targetFlutter: targetFlutter,
    );
    final findings = [
      ...runRules(projectRules, ctx, ignore: ignore),
      ...runRules(pluginRules, ctx, ignore: ignore),
    ];
    final plan = FixPlanner(
      snapshot: snapshot,
      matrix: matrix,
      findings: findings,
      release: ctx.release,
    ).plan();

    final preview = EditApplier.preview(plan.edits);
    final before = {
      for (final path in preview.keys)
        path: File(path).existsSync() ? File(path).readAsStringSync() : '',
    };
    String display(String path) =>
        relativeForDisplay(path, from: snapshot.projectDir);

    if (jsonOutput) {
      // One JSON document, whatever happens. Without --yes nothing is
      // applied: a machine reader cannot answer the confirmation question.
      final apply = yes && !dryRun && !plan.isEmpty;
      final backup = apply
          ? BackupManager(snapshot.projectDir).backup(preview.keys)
          : null;
      if (apply) EditApplier.write(preview);
      final verification = apply && verify
          ? await _verifyQuietly(snapshot.projectDir)
          : null;
      final plain = DiffPrinter(Ansi(enabled: false));
      out(
        JsonReporter.encode({
          'tool': 'android_build_doctor',
          'version': packageVersion,
          'command': 'fix',
          'dry_run': dryRun,
          'plan': plan.toJson(),
          'diff': {
            for (final e in preview.entries)
              display(e.key): plain.unified(
                display(e.key),
                before[e.key]!,
                e.value,
              ),
          },
          'applied': apply,
          if (backup != null) 'backup': toPosixPath(backup),
          'verify': ?verification,
        }),
      );
      final failed = (verification?['exit_code'] ?? 0) != 0;
      return failed ? exitErrors : exitOk;
    }

    final report = FixReporter(painter);
    reporter.header(packageVersion, matrix);
    out('');
    if (plan.isEmpty) {
      report.nothingToFix(
        remaining: findings.where((f) => f.severity != Severity.info).length,
      );
      report.advice(plan.advice);
      return exitOk;
    }
    report.plan(plan, files: preview.length);
    for (final e in preview.entries) {
      report.diff(display(e.key), before[e.key]!, e.value);
    }
    report.advice(plan.advice);
    report.summary(plan, dryRun: dryRun);
    if (dryRun) {
      report.dryRun();
      return exitOk;
    }

    if (!yes) {
      if (await _gitDirty(snapshot.projectDir)) {
        painter.wrapped(
          ' ${painter.symbol(Severity.warning)} ',
          'android/ has uncommitted changes. A backup is made in '
              'android/${BackupManager.dirName}/ anyway.',
        );
      }
      spinner.stop();
      stdout.write(report.prompt);
      final answer = stdin.readLineSync()?.trim().toLowerCase();
      if (answer != 'y' && answer != 'yes') {
        report.aborted();
        return exitOk;
      }
    }

    final backup = BackupManager(snapshot.projectDir).backup(preview.keys);
    EditApplier.write(preview);
    report.applied(
      edits: plan.edits.length,
      files: preview.length,
      backup: display(backup),
      temporaryKgpFlag: plan.temporaryKgpFlag,
    );
    if (verify) return await _verify(snapshot.projectDir, report);
    return exitOk;
  }

  Future<bool> _gitDirty(String dir) async {
    final r = await defaultRunProcess('git', [
      'status',
      '--porcelain',
      '--',
      'android',
    ], workingDirectory: dir);
    if (r == null || r.exitCode != 0) return false;
    return r.stdout.toString().trim().isNotEmpty;
  }

  String get _flutter => Platform.isWindows ? 'flutter.bat' : 'flutter';

  Future<int> _verify(String dir, FixReporter report) async {
    report.verifying();
    final clean = await Process.run(
      _flutter,
      ['clean'],
      workingDirectory: dir,
      runInShell: Platform.isWindows,
    );
    if (clean.exitCode != 0) {
      err(clean.stderr.toString());
      return exitErrors;
    }
    final build = await Process.start(
      _flutter,
      ['build', 'apk', '--debug'],
      workingDirectory: dir,
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await build.exitCode;
    report.verified(code);
    return code == 0 ? exitOk : exitErrors;
  }

  /// `--verify` for `--json`: the build output is captured, not shown, so
  /// the JSON document stays the only thing on stdout.
  Future<Map<String, Object?>> _verifyQuietly(String dir) async {
    for (final args in [
      ['clean'],
      ['build', 'apk', '--debug'],
    ]) {
      final r = await Process.run(
        _flutter,
        args,
        workingDirectory: dir,
        runInShell: Platform.isWindows,
      );
      if (r.exitCode != 0 || args.length > 1) {
        return {
          'command': 'flutter ${args.join(' ')}',
          'exit_code': r.exitCode,
        };
      }
    }
    return const {};
  }
}
