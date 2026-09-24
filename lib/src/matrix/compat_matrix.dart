import 'package:yaml/yaml.dart';

import '../util/versions.dart';

/// A set of Java / KGP / AGP / Gradle versions.
class VersionSet {
  /// Creates a version set.
  const VersionSet({this.java, this.kgp, this.agp, this.gradle});

  /// Parses a YAML map such as `{ java: "17", agp: "9.1.0" }`.
  factory VersionSet.fromYaml(Object? node) {
    if (node is! Map) return const VersionSet();
    String? s(Object? v) => v?.toString();
    return VersionSet(
      java: s(node['java']),
      kgp: s(node['kgp']),
      agp: s(node['agp']),
      gradle: s(node['gradle']),
    );
  }

  /// Java major version, as a string.
  final String? java;

  /// Kotlin Gradle Plugin version.
  final String? kgp;

  /// Android Gradle Plugin version.
  final String? agp;

  /// Gradle version.
  final String? gradle;

  /// Whether every field is null.
  bool get isEmpty =>
      java == null && kgp == null && agp == null && gradle == null;

  /// JSON representation.
  Map<String, Object?> toJson() => {
    'java': java,
    'kgp': kgp,
    'agp': agp,
    'gradle': gradle,
  };
}

/// Default SDK levels vended by a Flutter release.
class SdkDefaults {
  /// Creates SDK defaults.
  const SdkDefaults({this.compileSdk, this.targetSdk, this.minSdk, this.ndk});

  /// Parses a YAML map.
  factory SdkDefaults.fromYaml(Object? node) {
    if (node is! Map) return const SdkDefaults();
    int? i(Object? v) => v == null ? null : int.tryParse(v.toString());
    return SdkDefaults(
      compileSdk: i(node['compileSdk']),
      targetSdk: i(node['targetSdk']),
      minSdk: i(node['minSdk']),
      ndk: node['ndk']?.toString(),
    );
  }

  /// `flutter.compileSdkVersion`.
  final int? compileSdk;

  /// `flutter.targetSdkVersion`.
  final int? targetSdk;

  /// `flutter.minSdkVersion`.
  final int? minSdk;

  /// `flutter.ndkVersion`.
  final String? ndk;

  /// JSON representation.
  Map<String, Object?> toJson() => {
    'compileSdk': compileSdk,
    'targetSdk': targetSdk,
    'minSdk': minSdk,
    'ndk': ndk,
  };
}

/// What the matrix knows about one Flutter `major.minor` release.
class FlutterRelease {
  /// Creates a release entry.
  const FlutterRelease({
    required this.series,
    required this.verified,
    required this.minimums,
    required this.warnBelow,
    required this.maxKnown,
    required this.defaults,
    required this.builtInKotlinSupported,
    required this.legacyKgpFlag,
    this.agp8Combo,
    this.maxRecommendedAgp,
  });

  /// Parses one entry of the `flutter:` map.
  factory FlutterRelease.fromYaml(String series, Object? node) {
    final map = node is Map ? node : const {};
    final bik = map['builtin_kotlin'];
    final bikMap = bik is Map ? bik : const {};
    final combo = map['agp8_combo'];
    return FlutterRelease(
      series: series,
      verified: VersionSet.fromYaml(map['verified']),
      minimums: VersionSet.fromYaml(map['minimums']),
      warnBelow: VersionSet.fromYaml(map['warn_below']),
      maxKnown: VersionSet.fromYaml(map['max_known']),
      defaults: SdkDefaults.fromYaml(map['defaults']),
      builtInKotlinSupported: bikMap['supported'] == true,
      legacyKgpFlag: bikMap['legacy_kgp_flag'] == true,
      agp8Combo: combo is Map ? VersionSet.fromYaml(combo) : null,
      maxRecommendedAgp: map['max_recommended_agp']?.toString(),
    );
  }

  /// `major.minor`, for example `3.47`.
  final String series;

  /// Versions Flutter's template ships with for this release.
  final VersionSet verified;

  /// Below these, Flutter's Gradle plugin fails the build.
  final VersionSet minimums;

  /// Below these, Flutter's Gradle plugin warns that support will be dropped.
  final VersionSet warnBelow;

  /// Newest versions Flutter's tooling knows about.
  final VersionSet maxKnown;

  /// `flutter.*SdkVersion` defaults.
  final SdkDefaults defaults;

  /// Whether `android.builtInKotlin=true` is supported.
  final bool builtInKotlinSupported;

  /// Whether `android.builtInKotlin=false` (legacy KGP on AGP 9) works.
  final bool legacyKgpFlag;

  /// Newest AGP 8 combination known to work with this release.
  final VersionSet? agp8Combo;

  /// AGP major version the Flutter team told users not to exceed, if any.
  final String? maxRecommendedAgp;

  /// JSON representation.
  Map<String, Object?> toJson() => {
    'series': series,
    'verified': verified.toJson(),
    'minimums': minimums.toJson(),
    'warn_below': warnBelow.toJson(),
    'max_known': maxKnown.toJson(),
    'defaults': defaults.toJson(),
    'builtin_kotlin': {
      'supported': builtInKotlinSupported,
      'legacy_kgp_flag': legacyKgpFlag,
    },
    'agp8_combo': agp8Combo?.toJson(),
    'max_recommended_agp': maxRecommendedAgp,
  };
}

/// One AGP release series and its requirements.
class AgpSeries {
  /// Creates an AGP series entry.
  const AgpSeries({required this.series, this.minGradle, this.minJdk});

  /// `major.minor`, for example `9.1`.
  final String series;

  /// Minimum Gradle for this AGP.
  final String? minGradle;

  /// Minimum JDK to run this AGP.
  final int? minJdk;
}

/// A Gradle version paired with a Java major version.
class GradleJava {
  /// Creates a pair.
  const GradleJava(this.gradle, this.java);

  /// Gradle version.
  final String gradle;

  /// Java major version.
  final int java;
}

/// The parsed compatibility matrix (`data/matrix.yaml`).
class CompatMatrix {
  /// Creates a matrix.
  const CompatMatrix({
    required this.schemaVersion,
    required this.updated,
    required this.latestFlutter,
    required this.sources,
    required this.flutter,
    required this.agp,
    required this.gradleMaxJava,
    required this.gradleMinJava,
    required this.javaClassVersions,
    required this.namespaceRequiredFrom,
    required this.builtInKotlinFrom,
    required this.pluginCompileSdkLag,
    required this.pluginJavaBelow,
    required this.source,
    this.rawYaml,
  });

  /// Parses `yamlText`. `source` describes where it came from
  /// (`bundled`, `remote` or `cache`).
  factory CompatMatrix.parse(String yamlText, {required String source}) {
    final doc = loadYaml(yamlText);
    if (doc is! Map) {
      throw const FormatException('matrix.yaml: top level must be a map');
    }
    final flutter = <String, FlutterRelease>{};
    final f = doc['flutter'];
    if (f is Map) {
      for (final entry in f.entries) {
        final key = entry.key.toString();
        flutter[key] = FlutterRelease.fromYaml(key, entry.value);
      }
    }
    final agp = <AgpSeries>[];
    final a = doc['agp'];
    if (a is List) {
      for (final row in a) {
        if (row is! Map) continue;
        agp.add(
          AgpSeries(
            series: row['series'].toString(),
            minGradle: row['min_gradle']?.toString(),
            minJdk: row['min_jdk'] is int ? row['min_jdk'] as int : null,
          ),
        );
      }
    }
    List<GradleJava> gj(Object? node) {
      final out = <GradleJava>[];
      if (node is List) {
        for (final row in node) {
          if (row is! Map) continue;
          final java = row['java'];
          if (java is! int) continue;
          out.add(GradleJava(row['gradle'].toString(), java));
        }
      }
      out.sort((x, y) => Versions.compare(y.gradle, x.gradle));
      return out;
    }

    final classes = <int, String>{};
    final jc = doc['java_class_versions'];
    if (jc is Map) {
      for (final e in jc.entries) {
        final k = int.tryParse(e.key.toString());
        if (k != null) classes[k] = e.value.toString();
      }
    }
    final features = doc['agp_features'];
    final fm = features is Map ? features : const {};
    final audit = doc['plugin_audit'];
    final am = audit is Map ? audit : const {};
    final sources = <String>[];
    final s = doc['sources'];
    if (s is List) sources.addAll(s.map((e) => e.toString()));

    return CompatMatrix(
      schemaVersion: doc['schema_version'] is int
          ? doc['schema_version'] as int
          : 1,
      updated: doc['updated']?.toString() ?? 'unknown',
      latestFlutter:
          doc['latest_flutter']?.toString() ??
          (flutter.keys.isEmpty ? 'unknown' : flutter.keys.first),
      sources: sources,
      flutter: flutter,
      agp: agp,
      gradleMaxJava: gj(doc['gradle_max_java']),
      gradleMinJava: gj(doc['gradle_min_java']),
      javaClassVersions: classes,
      namespaceRequiredFrom: fm['namespace_required_from']?.toString() ?? '8.0',
      builtInKotlinFrom: fm['builtin_kotlin_from']?.toString() ?? '9.0',
      pluginCompileSdkLag: am['compile_sdk_lag'] is int
          ? am['compile_sdk_lag'] as int
          : 2,
      pluginJavaBelow: am['java_below'] is int ? am['java_below'] as int : 11,
      source: source,
      rawYaml: yamlText,
    );
  }

  /// `schema_version`.
  final int schemaVersion;

  /// `updated` date (ISO string).
  final String updated;

  /// Newest Flutter series in the matrix.
  final String latestFlutter;

  /// Source URLs the data was taken from.
  final List<String> sources;

  /// Flutter entries keyed by `major.minor`.
  final Map<String, FlutterRelease> flutter;

  /// AGP series, newest first as listed.
  final List<AgpSeries> agp;

  /// Gradle → max Java rows, newest Gradle first.
  final List<GradleJava> gradleMaxJava;

  /// Gradle → min Java rows, newest Gradle first.
  final List<GradleJava> gradleMinJava;

  /// Class-file major → Java version.
  final Map<int, String> javaClassVersions;

  /// AGP version from which `namespace` is mandatory.
  final String namespaceRequiredFrom;

  /// AGP version from which Kotlin is built in.
  final String builtInKotlinFrom;

  /// Plugin audit: `compileSdk` lag before warning.
  final int pluginCompileSdkLag;

  /// Plugin audit: warn when a plugin targets Java below this.
  final int pluginJavaBelow;

  /// `bundled`, `remote` or `cache`.
  final String source;

  /// The YAML text this matrix was parsed from.
  final String? rawYaml;

  /// Flutter series sorted newest first.
  List<String> get flutterSeries {
    final keys = flutter.keys.toList()..sort((a, b) => Versions.compare(b, a));
    return keys;
  }

  /// The entry for `flutterVersion` (`3.47.1` → `3.47`). When the exact
  /// series is unknown, the nearest *older* known series is returned so a
  /// brand-new Flutter still gets sensible advice; `null` when nothing older
  /// exists either.
  FlutterRelease? releaseFor(String? flutterVersion) {
    if (flutterVersion == null) return null;
    final series = Versions.majorMinor(flutterVersion);
    final exact = flutter[series];
    if (exact != null) return exact;
    for (final key in flutterSeries) {
      if (Versions.compare(key, series) <= 0) return flutter[key];
    }
    return null;
  }

  /// True when the matrix has an exact row for the version's series.
  bool hasExactRelease(String? flutterVersion) =>
      flutterVersion != null &&
      flutter.containsKey(Versions.majorMinor(flutterVersion));

  /// The newest Flutter entry.
  FlutterRelease? get latest =>
      flutter[latestFlutter] ?? releaseFor(latestFlutter);

  /// The AGP series row for a full AGP version.
  AgpSeries? agpSeries(String? agpVersion) {
    if (agpVersion == null) return null;
    final mm = Versions.majorMinor(agpVersion);
    for (final row in agp) {
      if (row.series == mm) return row;
    }
    return null;
  }

  /// Minimum Gradle for an AGP version, or `null` when unknown.
  String? minGradleForAgp(String? agpVersion) =>
      agpSeries(agpVersion)?.minGradle;

  /// Minimum JDK for an AGP version, or `null` when unknown.
  int? minJdkForAgp(String? agpVersion) => agpSeries(agpVersion)?.minJdk;

  /// Newest Java a Gradle version can run on, or `null` when unknown.
  int? maxJavaForGradle(String? gradleVersion) {
    if (gradleVersion == null) return null;
    for (final row in gradleMaxJava) {
      if (Versions.atLeast(gradleVersion, row.gradle)) return row.java;
    }
    return null;
  }

  /// Oldest Java a Gradle version can run on, or `null` when unknown.
  int? minJavaForGradle(String? gradleVersion) {
    if (gradleVersion == null) return null;
    for (final row in gradleMinJava) {
      if (Versions.atLeast(gradleVersion, row.gradle)) return row.java;
    }
    return null;
  }

  /// Minimum Gradle that can run on `javaMajor`, or `null` when unknown.
  String? minGradleForJava(int javaMajor) {
    for (final row in gradleMaxJava.reversed) {
      if (row.java >= javaMajor) return row.gradle;
    }
    return null;
  }

  /// Java version for a class-file major (61 → `17`).
  String javaForClassFile(int major) =>
      javaClassVersions[major] ?? '${Versions.javaFromClassFileMajor(major)}';

  /// JSON representation used by `matrix --json`.
  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'updated': updated,
    'source': source,
    'latest_flutter': latestFlutter,
    'sources': sources,
    'flutter': {for (final e in flutter.entries) e.key: e.value.toJson()},
    'agp': [
      for (final a in agp)
        {'series': a.series, 'min_gradle': a.minGradle, 'min_jdk': a.minJdk},
    ],
    'gradle_max_java': [
      for (final g in gradleMaxJava) {'gradle': g.gradle, 'java': g.java},
    ],
    'gradle_min_java': [
      for (final g in gradleMinJava) {'gradle': g.gradle, 'java': g.java},
    ],
    'java_class_versions': {
      for (final e in javaClassVersions.entries) '${e.key}': e.value,
    },
  };
}
