import '../model/finding.dart';
import 'gd_rules.dart';
import 'gp_rules.dart';
import 'rule.dart';

export 'gd_rules.dart';
export 'gp_rules.dart';
export 'rule.dart';

/// Rules run by `android_build_doctor check`.
const List<Rule> projectRules = [
  Gd001JavaTooOld(),
  Gd002GradleBelowAgp(),
  Gd003JavaTooNewForGradle(),
  Gd004OlderThanVerified(),
  Gd005KgpConflictsWithBuiltInKotlin(),
  Gd006LegacyKgpFlag(),
  Gd007BuiltInKotlinBlockedByPlugins(),
  Gd008ImperativeApply(),
  Gd009MissingNamespace(),
  Gd010JvmTargetMismatch(),
  Gd011HardcodedSdk(),
  Gd012MinSdkBelowDefault(),
  Gd013Jcenter(),
  Gd014OldProjectTemplate(),
  Gd015CiJavaMismatch(),
  Gd016BelowFlutterMinimum(),
];

/// Rules run by `android_build_doctor plugins`.
const List<Rule> pluginRules = [
  Gp001PluginAppliesKgp(),
  Gp002PluginMissingNamespace(),
  Gp003PluginJcenter(),
  Gp004PluginOldSettings(),
  Gp005PluginOutdated(),
];

/// Runs `rules` against `ctx`, skipping ids in `ignore`, sorted by severity
/// then id.
List<Finding> runRules(
  Iterable<Rule> rules,
  RuleContext ctx, {
  Set<String> ignore = const {},
}) {
  final out = <Finding>[
    for (final r in rules)
      if (!ignore.contains(r.id)) ...r.evaluate(ctx),
  ];
  out.sort((a, b) {
    final c = a.severity.rank.compareTo(b.severity.rank);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return out;
}
