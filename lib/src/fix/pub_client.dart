import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up the newest version of packages on pub.dev.
class PubClient {
  /// Creates a client. `baseUrl` is overridable for tests.
  PubClient({
    http.Client? client,
    this.baseUrl = 'https://pub.dev/api/packages',
    this.timeout = const Duration(seconds: 5),
    this.concurrency = 8,
  }) : _client = client;

  final http.Client? _client;

  /// API base URL.
  final String baseUrl;

  /// Per-request timeout.
  final Duration timeout;

  /// How many requests run at once.
  final int concurrency;

  /// Newest version of `package`, or `null` on any failure.
  Future<String?> latestVersion(String package, {http.Client? client}) async {
    final c = client ?? _client ?? http.Client();
    try {
      final r = await c
          .get(
            Uri.parse('$baseUrl/$package'),
            headers: const {
              'Accept': 'application/vnd.pub.v2+json',
              'User-Agent':
                  'android_build_doctor (https://pub.dev/packages/android_build_doctor)',
            },
          )
          .timeout(timeout);
      if (r.statusCode != 200) return null;
      final json = jsonDecode(r.body);
      if (json is Map && json['latest'] is Map) {
        return (json['latest'] as Map)['version']?.toString();
      }
      return null;
    } on Object {
      return null;
    } finally {
      if (client == null && _client == null) c.close();
    }
  }

  /// Newest versions for many packages, `null` where unknown.
  Future<Map<String, String?>> latestVersions(Iterable<String> packages) async {
    final names = packages.toList();
    final out = <String, String?>{};
    final c = _client ?? http.Client();
    try {
      for (var i = 0; i < names.length; i += concurrency) {
        final batch = names.sublist(
          i,
          (i + concurrency).clamp(0, names.length),
        );
        final results = await Future.wait(
          batch.map((n) => latestVersion(n, client: c)),
        );
        for (var j = 0; j < batch.length; j++) {
          out[batch[j]] = results[j];
        }
      }
    } finally {
      if (_client == null) c.close();
    }
    return out;
  }
}
