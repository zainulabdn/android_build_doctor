import '../fix/backup_manager.dart';
import '../model/severity.dart';
import '../util/paths.dart';
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
  Future<int> execute() async {
    final dir = projectDir;
    final manager = BackupManager(dir);
    final backups = manager.list();
    final where = 'android/${BackupManager.dirName}/';
    if (argResults!['list'] == true) {
      if (backups.isEmpty) {
        out(' ${painter.symbol(Severity.info)} No backups in $where');
        return exitOk;
      }
      out(' ${ansi.bold('Backups')} ${ansi.dim('in $where, newest first')}');
      for (final b in backups) {
        out(
          '   ${ansi.dim(glyphs.bullet)} ${relativeForDisplay(b.path, from: dir)}',
        );
      }
      return exitOk;
    }
    if (backups.isEmpty) {
      out(
        ' ${painter.symbol(Severity.info)} Nothing to restore: no backups in '
        '$where',
      );
      return exitOk;
    }
    final newest = relativeForDisplay(backups.first.path, from: dir);
    final restored = manager.restore();
    if (restored.isEmpty) {
      throw const ToolExit(
        'Backup manifest missing or empty; nothing restored.',
      );
    }
    out(
      ' ${painter.symbol(null)} ${ansi.bold('Restored')} '
      '${restored.length} file${restored.length == 1 ? '' : 's'} '
      '${ansi.dim('from $newest')}',
    );
    for (final f in restored) {
      out('   ${ansi.dim(glyphs.bullet)} $f');
    }
    return exitOk;
  }
}
