import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../data/bundled_data.dart';
import '../util/versions.dart';
import 'compat_matrix.dart';

/// Default location of the community-maintained matrix.
const String defaultMatrixUrl =
    'https://raw.githubusercontent.com/zainulabdn/android_build_doctor/main/data/matrix.yaml';

/// Loads the compatibility matrix: remote (cached for 24 hours) with the
/// bundled copy as fallback. The freshest copy (by `updated` date) wins.
class MatrixLoader {
  /// Creates a loader. All parameters have production defaults; tests
  /// override them.
  MatrixLoader({
    http.Client? client,
    String? cacheDir,
    this.remoteUrl = defaultMatrixUrl,
    this.timeout = const Duration(seconds: 3),
    this.cacheTtl = const Duration(hours: 24),
    String? bundledYaml,
  }) : _client = client,
       _cacheDir = cacheDir,
       _bundledYaml = bundledYaml ?? bundledMatrixYaml;

  final http.Client? _client;
  final String? _cacheDir;
  final String _bundledYaml;

  /// URL of the remote matrix.
  final String remoteUrl;

  /// How long to wait for the remote fetch.
  final Duration timeout;

  /// How long a cached remote copy stays fresh.
  final Duration cacheTtl;

  /// Notes about what happened during loading (for `--verbose`).
  final List<String> notes = [];

  /// The bundled matrix, parsed.
  CompatMatrix get bundled =>
      CompatMatrix.parse(_bundledYaml, source: 'bundled');

  /// Environment variable that overrides [cacheDirectory]. Useful in tests
  /// and in CI, where the matrix cache must not leak between runs.
  static const String cacheDirEnvVar = 'ANDROID_BUILD_DOCTOR_CACHE_DIR';

  /// Directory where the remote copy is cached.
  String get cacheDirectory {
    if (_cacheDir != null) return _cacheDir;
    final override = Platform.environment[cacheDirEnvVar];
    if (override != null && override.isNotEmpty) return override;
    final home =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    return p.join(home, '.android_build_doctor');
  }

  File get _cacheFile => File(p.join(cacheDirectory, 'matrix.yaml'));

  /// Loads the matrix. With `offline`, no network request is made (a cached
  /// copy is still used if it is newer than the bundled one).
  Future<CompatMatrix> load({bool offline = false}) async {
    final candidates = <CompatMatrix>[bundled];

    final cached = _readCache(allowStale: offline);
    if (cached != null) {
      candidates.add(cached);
    } else if (!offline) {
      final remote = await _fetchRemote();
      if (remote != null) candidates.add(remote);
    }

    // Freshest date wins. On a tie the remote copy is preferred over the
    // cache, and both over the bundled fallback: they are at least as fresh,
    // and the report footer should show that remote updating is working.
    candidates.sort((a, b) {
      final byDate = Versions.compare(_dateKey(b), _dateKey(a));
      return byDate != 0 ? byDate : _sourceRank(a).compareTo(_sourceRank(b));
    });
    final chosen = candidates.first;
    notes.add('using ${chosen.source} matrix dated ${chosen.updated}');
    return chosen;
  }

  static String _dateKey(CompatMatrix m) => m.updated.replaceAll('-', '.');

  static int _sourceRank(CompatMatrix m) => switch (m.source) {
    'remote' => 0,
    'cache' => 1,
    _ => 2,
  };

  CompatMatrix? _readCache({required bool allowStale}) {
    final f = _cacheFile;
    if (!f.existsSync()) return null;
    final age = DateTime.now().difference(f.lastModifiedSync());
    if (!allowStale && age > cacheTtl) {
      notes.add('cache is ${age.inHours}h old, refreshing');
      return null;
    }
    try {
      return CompatMatrix.parse(f.readAsStringSync(), source: 'cache');
    } on Object catch (e) {
      notes.add('ignoring unreadable cache: $e');
      return null;
    }
  }

  Future<CompatMatrix?> _fetchRemote() async {
    final client = _client ?? http.Client();
    try {
      final response = await client.get(Uri.parse(remoteUrl)).timeout(timeout);
      if (response.statusCode != 200) {
        notes.add('remote matrix returned HTTP ${response.statusCode}');
        return null;
      }
      final matrix = CompatMatrix.parse(response.body, source: 'remote');
      _writeCache(response.body);
      return matrix;
    } on Object catch (e) {
      notes.add('remote matrix unavailable: ${e.runtimeType}');
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  void _writeCache(String yaml) {
    try {
      _cacheFile.parent.createSync(recursive: true);
      _cacheFile.writeAsStringSync(yaml);
    } on FileSystemException catch (e) {
      notes.add('could not write cache: ${e.message}');
    }
  }
}
