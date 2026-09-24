import 'dart:io';

import 'package:path/path.dart' as p;

/// Paths that appear in reports and in `--json` output are always written with
/// forward slashes, on every platform.
///
/// `package:path` returns `android\app\build.gradle` on Windows, which would
/// make the machine-readable output platform-dependent and would not match the
/// way Flutter and Gradle documentation spell these paths. Filesystem access
/// keeps using native separators; only what the user and tools see is
/// normalised.
///
/// `windows` is exposed so the conversion can be tested on any host.
String toPosixPath(String path, {bool? windows}) =>
    (windows ?? Platform.isWindows) ? path.replaceAll(r'\', '/') : path;

/// Converts a report path (forward slashes) back to a native filesystem path.
String toNativePath(String path, {bool? windows}) =>
    (windows ?? Platform.isWindows) ? path.replaceAll('/', r'\') : path;

/// `p.relative`, normalised for display.
String relativeForDisplay(String path, {required String from}) =>
    toPosixPath(p.relative(path, from: from));
