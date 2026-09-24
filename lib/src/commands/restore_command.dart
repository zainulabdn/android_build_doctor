import 'package:path/path.dart' as p;

import '../fix/backup_manager.dart';
import 'base_command.dart';

/// `android_build_doctor restore`.
class RestoreCommand extends BaseCommand {
  /// Creates the command.
  RestoreCommand() {
    argParser.addFlag(
      'list',
      help: 'List available backups and exit.',
      negatable: false,
    );
  }

  @override
  String get name => 'restore';

  @override
  String get description =>
      'Undo the most recent `fix` by restoring its backup.';

  @override
  Future<int> run() async {
    final dir = projectDir;
    final manager = BackupManager(dir);
    final backups = manager.list();
    if (argResults!['list'] == true) {
      if (backups.isEmpty) {
        out('No backups in android/${BackupManager.dirName}/.');
      }
      for (final b in backups) {
        out(p.relative(b.path, from: dir));
      }
      return exitOk;
    }
    if (backups.isEmpty) {
      out(
        'Nothing to restore: no backups in android/${BackupManager.dirName}/.',
      );
      return exitOk;
    }
    final restored = manager.restore();
    if (restored.isEmpty) {
      throw const ToolExit(
        'Backup manifest missing or empty; nothing restored.',
      );
    }
    out(ansi.green('Restored ${restored.length} file(s):'));
    for (final f in restored) {
      out('  $f');
    }
    return exitOk;
  }
}
