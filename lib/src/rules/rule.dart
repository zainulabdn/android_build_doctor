import '../matrix/compat_matrix.dart';
import '../model/finding.dart';
import '../model/project_snapshot.dart';

/// Everything a rule may look at. Rules are pure functions of this object.
class RuleContext {
  /// Creates a context. When `targetFlutter` is given, rules evaluate the
  /// project as if it ran on that Flutter release (the upgrade planner).
  RuleContext({
    required this.snapshot,
    required this.matrix,
    this.targetFlutter,
  }) : release = matrix.releaseFor(
         targetFlutter ?? snapshot.flutterVersion?.value,
       );

  /// The detected project.
  final ProjectSnapshot snapshot;

  /// The compatibility matrix.
  final CompatMatrix matrix;

  /// Flutter version being planned for, or `null` for the current one.
  final String? targetFlutter;

  /// Matrix entry for the Flutter version in play (may be `null`).
  final FlutterRelease? release;

  /// The Flutter version in play (target, else detected).
  String? get flutterVersion => targetFlutter ?? snapshot.flutterVersion?.value;

  /// Human label for the Flutter version in play.
  String get flutterLabel => flutterVersion == null
      ? 'this Flutter'
      : 'Flutter ${release?.series ?? flutterVersion}';
}

/// A diagnostic rule with a stable id.
abstract class Rule {
  /// Creates a rule.
  const Rule();

  /// Stable identifier such as `GD005`.
  String get id;

  /// One-line description for `--help` and documentation.
  String get description;

  /// Evaluates the rule. Must not touch the file system or network.
  List<Finding> evaluate(RuleContext ctx);
}
