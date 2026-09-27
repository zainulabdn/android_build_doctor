import '../fix/pub_client.dart';
import '../model/plugin_info.dart';
import '../model/severity.dart';
import '../output/json_reporter.dart';
import '../output/painter.dart';
import '../output/plugins_reporter.dart';
import '../rules/rules.dart';
import '../version.dart';
import 'base_command.dart';

/// `android_build_doctor plugins`.
class PluginsCommand extends BaseCommand {
  /// Creates the command.
  PluginsCommand() {
    argParser
      ..addFlag(
        'all',
        help: 'List every plugin, including the ones with no findings.',
        negatable: false,
      )
      ..addMultiOption('ignore', help: 'Rule ids to skip.', valueHelp: 'GP005');
  }

  @override
  String get name => 'plugins';

  @override
  String get description =>
      'Scan every Android plugin in the dependency tree for AGP 9 / '
      'built-in Kotlin blockers and other problems.';

  @override
  Future<int> execute() async {
    final matrix = await loadMatrix();
    var snapshot = await detectProject(scanPlugins: true);
    if (snapshot == null) return exitOk;
    if (snapshot.dartToolMissing) {
      throw ToolExit(
        '.dart_tool/package_config.json not found. '
        'Run `flutter pub get` first.',
      );
    }
    if (!offline && snapshot.plugins.isNotEmpty) {
      spinner.start(
        'Looking up ${Painter.plural(snapshot.plugins.length, 'plugin')} '
        'on pub.dev',
      );
      final latest = await PubClient().latestVersions(
        snapshot.plugins.where((p) => !p.isPathDependency).map((p) => p.name),
      );
      snapshot = snapshot.withPlugins([
        for (final p in snapshot.plugins) p.withLatestVersion(latest[p.name]),
      ]);
    }
    final ignore = (argResults!['ignore'] as List<String>).toSet();
    final ctx = RuleContext(
      snapshot: snapshot,
      matrix: matrix,
      targetFlutter: targetFlutter,
    );
    final findings = runRules(pluginRules, ctx, ignore: ignore);
    final code = findings.any((f) => f.severity == Severity.error)
        ? exitErrors
        : exitOk;

    if (jsonOutput) {
      out(
        JsonReporter.encode(
          JsonReporter.report(
            toolVersion: packageVersion,
            command: 'plugins',
            snapshot: snapshot,
            matrix: matrix,
            findings: findings,
            release: ctx.release,
            targetFlutter: targetFlutter,
            extra: {'verdict': _Verdict.of(snapshot.plugins).toJson()},
          ),
        ),
      );
      return code;
    }

    reporter.header(packageVersion, matrix);
    PluginsReporter(painter).report(
      snapshot: snapshot,
      findings: findings,
      offline: offline,
      showAll: argResults!['all'] == true,
      verbose: verbose,
    );
    return code;
  }
}

class _Verdict {
  const _Verdict({required this.total, required this.blockers});

  factory _Verdict.of(List<PluginInfo> plugins) => _Verdict(
    total: plugins.length,
    blockers: [
      for (final p in plugins)
        if (p.appliesKgp) p.name,
    ],
  );

  final int total;
  final List<String> blockers;
  int get ready => total - blockers.length;
  Map<String, Object?> toJson() => {
    'total': total,
    'ready': ready,
    'blockers': blockers,
  };
}
