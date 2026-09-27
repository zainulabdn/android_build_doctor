import '../model/finding.dart';
import '../model/plugin_info.dart';
import '../model/project_snapshot.dart';
import '../model/severity.dart';
import '../util/versions.dart';
import 'ansi.dart';
import 'painter.dart';

/// Renders the `plugins` report: the AGP 9 readiness meter, every plugin
/// with a problem (worst first), and a closing card.
class PluginsReporter {
  /// Creates a reporter that draws with `painter`.
  PluginsReporter(this.painter);

  /// The drawing primitives.
  final Painter painter;

  /// Prints the report. `findings` are the plugin rules' findings; with
  /// `showAll`, plugins without findings are listed too.
  void report({
    required ProjectSnapshot snapshot,
    required List<Finding> findings,
    bool offline = false,
    bool showAll = false,
    bool verbose = false,
  }) {
    final p = painter, a = p.ansi, g = p.glyphs, out = p.out;
    final s = snapshot;
    final flag = s.builtInKotlin == null
        ? 'unset'
        : '${s.builtInKotlin!.value}';
    out('');
    out(
      ' ${a.bold(s.projectName ?? '?')}  AGP ${s.agpVersion?.value ?? '?'} '
      '${a.dim(g.dot)} android.builtInKotlin=$flag',
    );
    p.wrapped(
      ' ',
      '${Painter.plural(s.plugins.length, 'plugin')} with an Android module '
          '(from .dart_tool/package_config.json)'
          '${offline ? ' ${g.dot} offline, no pub.dev lookups' : ''}',
      style: a.dim,
    );
    out('');
    p.panel(_readiness(s, findings), title: 'AGP 9 readiness');
    out('');

    final byPlugin = <String, List<Finding>>{};
    for (final f in findings) {
      (byPlugin[f.data['plugin']?.toString() ?? '?'] ??= []).add(f);
    }
    int rank(PluginInfo plugin) =>
        Painter.worstOf(byPlugin[plugin.name] ?? const [])?.rank ?? 3;
    final listed =
        [
          for (final plugin in s.plugins)
            if (showAll || byPlugin.containsKey(plugin.name)) plugin,
        ]..sort((x, y) {
          final c = rank(x).compareTo(rank(y));
          return c != 0 ? c : x.name.compareTo(y.name);
        });

    for (final plugin in listed) {
      final fs = byPlugin[plugin.name] ?? const <Finding>[];
      final newer =
          plugin.latestVersion != null &&
          plugin.version != null &&
          Versions.compare(plugin.latestVersion!, plugin.version!) > 0;
      out(
        ' ${p.symbol(Painter.worstOf(fs))} ${a.bold(plugin.name)} '
        '${plugin.version ?? ''}'
        '${newer ? a.dim('  ${g.arrow} ${plugin.latestVersion} available') : ''}'
        '${plugin.isPathDependency ? a.dim('  path dependency') : ''}',
      );
      for (final f in fs) {
        p.wrapped('   ${a.dim(f.id)}  ', _message(f, plugin));
        if (verbose && f.fix != null) {
          p.wrapped('          ${a.dim('fix')}  ', f.fix!);
        }
      }
      if (fs.isNotEmpty) out('');
    }
    if (findings.isEmpty && !showAll) {
      out(
        ' ${p.symbol(null)} No plugin problems found. '
        '${a.dim('Use --all to list every plugin.')}',
      );
      out('');
    } else if (listed.isNotEmpty && byPlugin[listed.last.name] == null) {
      out('');
    }

    final blockers = s.kgpPlugins;
    p.panel([
      p.counts(findings) ??
          '${p.symbol(null)} ${a.bold('No plugin problems found.')}',
      if (blockers.isNotEmpty)
        ...p.wrapLines(
          '${a.fg(Tones.accent, g.arrow)} ',
          'Upgrade the blockers, or ask their authors to migrate. Keep '
              'android.builtInKotlin=false until they are ready.',
          wrapWidth: p.innerWidth,
        ),
      if (!showAll && s.plugins.isNotEmpty)
        p.step('android_build_doctor plugins --all', 'list every plugin'),
    ], border: Painter.toneFor(Painter.worstOf(findings)));
  }

  List<String> _readiness(ProjectSnapshot s, List<Finding> findings) {
    final p = painter, a = p.ansi;
    final total = s.plugins.length;
    if (total == 0) return ['No Android plugins in the dependency tree.'];
    final blockers = s.kgpPlugins;
    final severe = findings.any(
      (f) => f.id == 'GP001' && f.severity == Severity.error,
    );
    final severity = blockers.isEmpty
        ? null
        : severe
        ? Severity.error
        : Severity.warning;
    final label = '${total - blockers.length}/$total ready';
    final cells = p.innerWidth - label.length - 1;
    return [
      '${p.meter(total - blockers.length, total, cells, Painter.toneFor(severity))} '
          '${a.bold(label)}',
      if (blockers.isEmpty)
        ...p.wrapLines(
          '${p.symbol(null)} ',
          'Every plugin is ready. You can set android.builtInKotlin=true '
              '(Flutter 3.47+).',
          wrapWidth: p.innerWidth,
        )
      else
        ...p.wrapLines(
          '${p.symbol(severity)} ',
          '${blockers.length == 1 ? '1 blocker' : '${blockers.length} blockers'}: '
              '${blockers.map((b) => b.name).join(', ')}',
          wrapWidth: p.innerWidth,
        ),
    ];
  }

  /// The finding's message without the `name version` prefix, which the
  /// plugin's own line already shows.
  String _message(Finding f, PluginInfo plugin) {
    if (f.id == 'GP005' && plugin.latestVersion != null) {
      return 'Newer release on pub.dev: ${plugin.version} '
          '${painter.glyphs.arrow} ${plugin.latestVersion}.';
    }
    final label = plugin.version == null
        ? plugin.name
        : '${plugin.name} ${plugin.version}';
    if (!f.message.startsWith('$label ')) return f.message;
    final rest = f.message.substring(label.length + 1);
    return rest.isEmpty ? rest : rest[0].toUpperCase() + rest.substring(1);
  }
}
