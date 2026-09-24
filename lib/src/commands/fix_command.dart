import 'dart:io';

import '../util/paths.dart';

import '../fix/backup_manager.dart';
import '../fix/diff_printer.dart';
import '../fix/file_edit.dart';
import '../fix/fix_planner.dart';
import '../model/severity.dart';
import '../output/json_reporter.dart';
import '../rules/rules.dart';
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
  Future<int> run() async {
    final dryRun = argResults!['dry-run'] == true;
    final yes = argResults!['yes'] == true || ci;
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
    final diffs = <String, String>{};
    final printer = DiffPrinter(ansi);
    for (final e in preview.entries) {
      final before = File(e.key).existsSync()
          ? File(e.key).readAsStringSync()
          : '';
      diffs[e.key] = printer.unified(
        relativeForDisplay(e.key, from: snapshot.projectDir),
        before,
        e.value,
      );
    }

    if (jsonOutput) {
      out(
        JsonReporter.encode({
          'tool': 'android_build_doctor',
          'version': packageVersion,
          'command': 'fix',
          'dry_run': dryRun,
          'plan': plan.toJson(),
          'diff': {
            for (final e in diffs.entries)
              relativeForDisplay(e.key, from: snapshot.projectDir): e.value,
          },
          'applied': false,
        }),
      );
      if (dryRun || plan.isEmpty) return exitOk;
    } else {
      reporter.header(packageVersion, matrix);
      out('');
      for (final r in plan.rationale) {
        out(ansi.dim('• $r'));
      }
      out('');
      if (plan.isEmpty) {
        out(ansi.green('Nothing to fix automatically.'));
        final remaining = findings
            .where((f) => f.severity != Severity.info)
            .length;
        if (remaining > 0) {
          out(
            '$remaining finding(s) need manual work; see `android_build_doctor check`.',
          );
        }
        for (final a in plan.advice) {
          out('${ansi.yellow('advice:')} $a');
        }
        return exitOk;
      }
      for (final d in diffs.values) {
        out(d);
      }
      out(
        '${plan.edits.length} edit(s) in ${diffs.length} file(s) addressing '
        '${plan.findingIds.join(', ')}.',
      );
      for (final a in plan.advice) {
        out('${ansi.yellow('advice:')} $a');
      }
      if (dryRun) {
        out('');
        out(ansi.dim('--dry-run: nothing written.'));
        return exitOk;
      }
    }

    // Safety: warn about a dirty git tree.
    if (!yes) {
      final dirty = await _gitDirty(snapshot.projectDir);
      if (dirty) {
        out(
          ansi.yellow(
            'Warning: android/ has uncommitted changes. A backup will '
            'be made in android/${BackupManager.dirName}/ anyway.',
          ),
        );
      }
      stdout.write('Apply these changes? (y/N) ');
      final answer = stdin.readLineSync()?.trim().toLowerCase();
      if (answer != 'y' && answer != 'yes') {
        out('Aborted. Nothing written.');
        return exitOk;
      }
    }

    final backup = BackupManager(snapshot.projectDir).backup(preview.keys);
    EditApplier.write(preview);
    if (jsonOutput) {
      out(JsonReporter.encode({'applied': true, 'backup': backup}));
    } else {
      out('');
      out(
        ansi.green('Applied.') +
            ansi.dim(
              ' Backup: ${relativeForDisplay(backup, from: snapshot.projectDir)}'
              ' (undo with `android_build_doctor restore`)',
            ),
      );
      out('Next: run `flutter clean && flutter build apk --debug` to verify.');
      if (plan.temporaryKgpFlag) {
        out(ansi.yellow('Reminder: android.builtInKotlin=false is temporary.'));
      }
    }

    if (argResults!['verify'] == true) {
      return await _verify(snapshot.projectDir);
    }
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

  Future<int> _verify(String dir) async {
    out('');
    out(ansi.bold('Verifying: flutter clean && flutter build apk --debug'));
    final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
    final clean = await Process.run(
      flutter,
      ['clean'],
      workingDirectory: dir,
      runInShell: Platform.isWindows,
    );
    if (clean.exitCode != 0) {
      err(clean.stderr.toString());
      return exitErrors;
    }
    final build = await Process.start(
      flutter,
      ['build', 'apk', '--debug'],
      workingDirectory: dir,
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await build.exitCode;
    out(
      code == 0
          ? ansi.green('Build succeeded.')
          : ansi.red(
              'Build failed (exit $code). Pipe the log into '
              '`android_build_doctor explain -` for a diagnosis.',
            ),
    );
    return code == 0 ? exitOk : exitErrors;
  }
}
