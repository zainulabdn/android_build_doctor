/// How serious a [Finding] is.
enum Severity {
  /// The build will (very likely) fail. Exit code 1 in `--ci` mode.
  error,

  /// Works today but is deprecated, unverified or risky.
  warning,

  /// A recommendation with no impact on the build.
  info;

  /// Lower-case label used in text and JSON output.
  String get label => name;

  /// Sort key: errors first.
  int get rank => switch (this) {
    Severity.error => 0,
    Severity.warning => 1,
    Severity.info => 2,
  };
}
