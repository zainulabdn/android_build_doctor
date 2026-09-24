import '../fix/pub_client.dart';
import '../model/finding.dart';
import '../model/plugin_info.dart';
import '../model/severity.dart';
import '../output/json_reporter.dart';
import '../rules/rules.dart';
import '../util/versions.dart';
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
  Future<int> run() async {
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
    final verdict = _verdict(snapshot.plugins);
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
            extra: {'verdict': verdict.toJson()},
          ),
        ),
      );
      return code;
    }

    reporter.header(packageVersion, matrix);
    out('');
    final agp = snapshot.agpVersion?.value;
    final bik = snapshot.builtInKotlin;
    out(
      '${ansi.bold('Project:')} ${snapshot.projectName ?? '?'}   '
      'AGP ${agp ?? '?'} ${ansi.dim('• android.builtInKotlin=${bik == null ? 'unset' : bik.value}')}'
      '${offline ? ansi.dim('  (offline: no pub.dev lookups)') : ''}',
    );
    out(
      '${snapshot.plugins.length} plugin(s) with an Android module found in .dart_tool/package_config.json',
    );
    out('');

    final byPlugin = <String, List<Finding>>{};
    for (final f in findings) {
      final name = f.data['plugin']?.toString() ?? '?';
      (byPlugin[name] ??= []).add(f);
    }
    final showAll = argResults!['all'] == true;
    for (final p in snapshot.plugins) {
      final fs = byPlugin[p.name] ?? const [];
      if (fs.isEmpty && !showAll) continue;
      final worst = fs.isEmpty ? null : fs.first.severity;
      final sym = reporter.symbolFor(worst);
      final latest =
          p.latestVersion != null &&
              p.version != null &&
              Versions.compare(p.latestVersion!, p.version!) > 0
          ? ansi.dim('  (latest ${p.latestVersion})')
          : '';
      out(
        '$sym ${ansi.bold(p.name)} ${p.version ?? ''}$latest'
        '${p.isPathDependency ? ansi.dim('  path dependency') : ''}',
      );
      for (final f in fs) {
        out('    ${ansi.dim(f.id)} ${f.message}');
        if (verbose && f.fix != null) out('      ${ansi.dim('fix:')} ${f.fix}');
      }
    }
    if (findings.isEmpty && !showAll) {
      out(
        ansi.green('No plugin problems found. Use --all to list every plugin.'),
      );
    }
    out('');
    reporter.summary(findings);
    out(_verdictLine(verdict));
    return code;
  }

  _Verdict _verdict(List<PluginInfo> plugins) {
    final blockers = plugins
        .where((p) => p.appliesKgp)
        .map((p) => p.name)
        .toList();
    return _Verdict(total: plugins.length, blockers: blockers);
  }

  String _verdictLine(_Verdict v) {
    final ready = v.total - v.blockers.length;
    final head = ansi.bold('AGP 9 + built-in Kotlin readiness: ');
    if (v.total == 0) return '${head}no Android plugins to check.';
    final score = v.blockers.isEmpty
        ? ansi.green('$ready/${v.total} plugins ready')
        : ansi.yellow('$ready/${v.total} plugins ready');
    final tail = v.blockers.isEmpty
        ? ansi.green(' You can set android.builtInKotlin=true (Flutter 3.47+).')
        : ' Blockers: ${ansi.red(v.blockers.join(', '))}.';
    return '$head$score.$tail';
  }
}

class _Verdict {
  const _Verdict({required this.total, required this.blockers});
  final int total;
  final List<String> blockers;
  int get ready => total - blockers.length;
  Map<String, Object?> toJson() => {
    'total': total,
    'ready': ready,
    'blockers': blockers,
  };
}
