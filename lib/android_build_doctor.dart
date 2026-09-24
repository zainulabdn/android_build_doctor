/// Android build doctor for Flutter.
///
/// Programmatic access to what the `android_build_doctor` CLI does:
///
/// ```dart
/// import 'package:android_build_doctor/android_build_doctor.dart';
///
/// Future<void> main() async {
///   final matrix = await MatrixLoader().load(offline: true);
///   final snapshot = await ProjectDetector().detect('/path/to/flutter_app',
///       scanPlugins: true);
///   final ctx = RuleContext(snapshot: snapshot, matrix: matrix);
///   for (final finding in runRules(projectRules, ctx)) {
///     print(finding);
///   }
/// }
/// ```
library;

export 'src/detect/app_gradle_detector.dart';
export 'src/detect/flutter_detector.dart';
export 'src/detect/gradle_patterns.dart';
export 'src/detect/gradle_properties_detector.dart';
export 'src/detect/gradle_versions_detector.dart';
export 'src/detect/java_detector.dart';
export 'src/detect/misc_detectors.dart';
export 'src/detect/plugins_detector.dart';
export 'src/detect/project_detector.dart';
export 'src/detect/version_catalog.dart';
export 'src/detect/wrapper_detector.dart';
export 'src/explain/error_pattern.dart';
export 'src/explain/explainer.dart';
export 'src/fix/backup_manager.dart';
export 'src/fix/diff_printer.dart';
export 'src/fix/file_edit.dart';
export 'src/fix/fix_planner.dart';
export 'src/fix/pub_client.dart';
export 'src/matrix/compat_matrix.dart';
export 'src/matrix/matrix_loader.dart';
export 'src/model/finding.dart';
export 'src/model/plugin_info.dart';
export 'src/model/project_snapshot.dart';
export 'src/model/sdk_level.dart';
export 'src/model/severity.dart';
export 'src/model/source_ref.dart';
export 'src/output/ansi.dart';
export 'src/output/console_reporter.dart';
export 'src/output/json_reporter.dart';
export 'src/rules/rules.dart';
export 'src/util/paths.dart';
export 'src/util/process.dart';
export 'src/util/text_file.dart';
export 'src/util/versions.dart';
export 'src/version.dart';
