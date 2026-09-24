import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/paths.dart';

/// Copies files into `android/.android_build_doctor_backup/<timestamp>/`
/// before they are changed, and restores the most recent backup.
class BackupManager {
  /// Creates a manager for the project at `projectDir`.
  BackupManager(this.projectDir);

  /// Name of the backup directory inside `android/`.
  static const String dirName = '.android_build_doctor_backup';

  /// Project root.
  final String projectDir;

  /// The backup root directory.
  String get root => p.join(projectDir, 'android', dirName);

  /// Backs up `paths` (absolute) and returns the backup directory created.
  String backup(Iterable<String> paths) {
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-')
        .substring(0, 19);
    final dir = Directory(p.join(root, stamp))..createSync(recursive: true);
    final manifest = <String, String>{};
    for (final path in paths) {
      final f = File(path);
      if (!f.existsSync()) continue;
      final rel = p.relative(path, from: projectDir);
      final dest = File(p.join(dir.path, rel));
      dest.parent.createSync(recursive: true);
      f.copySync(dest.path);
      manifest[rel] = dest.path;
    }
    File(p.join(dir.path, 'manifest.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'created': DateTime.now().toIso8601String(),
        'project': projectDir,
        'files': manifest.keys.toList(),
      }),
    );
    _ensureGitignore();
    return dir.path;
  }

  /// All backup directories, newest first.
  List<Directory> list() {
    final r = Directory(root);
    if (!r.existsSync()) return const [];
    final dirs = r.listSync().whereType<Directory>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return dirs;
  }

  /// Restores the newest backup (or `which`) and returns the restored paths,
  /// relative to the project root and written with forward slashes on every
  /// platform. Returns an empty list when there is nothing to restore.
  List<String> restore({Directory? which, bool delete = true}) {
    final dir = which ?? list().firstOrNull;
    if (dir == null) return const [];
    final manifestFile = File(p.join(dir.path, 'manifest.json'));
    if (!manifestFile.existsSync()) return const [];
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, Object?>;
    final files = (manifest['files'] as List).cast<String>();
    final restored = <String>[];
    for (final rel in files) {
      final src = File(p.join(dir.path, rel));
      if (!src.existsSync()) continue;
      final dest = File(p.join(projectDir, rel));
      dest.parent.createSync(recursive: true);
      src.copySync(dest.path);
      restored.add(toPosixPath(rel));
    }
    if (delete) dir.deleteSync(recursive: true);
    return restored;
  }

  void _ensureGitignore() {
    final gi = File(p.join(root, '.gitignore'));
    if (!gi.existsSync()) gi.writeAsStringSync('*\n');
  }
}
