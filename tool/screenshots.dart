// Renders the images in README.md and the pub.dev screenshots: the real
// reporters run against a generated demo project, drawn into a terminal
// window, then rasterised.
//
// Run with: dart run tool/screenshots.dart
//
// Writes doc/banner.webp and doc/screenshots/*.webp (lossless). Needs
// `rsvg-convert` and `cwebp` on PATH: `brew install librsvg webp`, or
// `apt install librsvg2-bin webp`. Pass --svg to keep the intermediate SVG
// files next to the images.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:android_build_doctor/src/data/bundled_data.dart';
import 'package:path/path.dart' as p;

const _width = 80;

Future<void> main(List<String> args) async {
  final keepSvg = args.contains('--svg');
  final out = Directory(p.join('doc', 'screenshots'))
    ..createSync(recursive: true);
  final matrix = CompatMatrix.parse(bundledMatrixYaml, source: 'remote');
  final demo = _DemoProject.create();
  try {
    // Order matters: `fix` edits the demo project, and `plugins` is shown
    // afterwards, with the android.builtInKotlin=false stop-gap in place.
    var snapshot = await demo.detect();
    var ctx = RuleContext(snapshot: snapshot, matrix: matrix);
    final check = _render((painter) {
      ConsoleReporter.withPainter(painter)
        ..header(packageVersion, matrix)
        ..report(
          snapshot: snapshot,
          matrix: matrix,
          findings: runRules(projectRules, ctx),
          release: ctx.release,
        );
    });

    final fix = _render((painter) {
      final plan = FixPlanner(
        snapshot: snapshot,
        matrix: matrix,
        findings: [
          ...runRules(projectRules, ctx),
          ...runRules(pluginRules, ctx),
        ],
        release: ctx.release,
      ).plan();
      final preview = EditApplier.preview(plan.edits);
      final report = FixReporter(painter);
      painter.header(packageVersion, matrix);
      painter.out('');
      report.plan(plan, files: preview.length);
      for (final e in preview.entries) {
        report.diff(
          relativeForDisplay(e.key, from: demo.app),
          File(e.key).readAsStringSync(),
          e.value,
        );
      }
      report.advice(plan.advice);
      report.summary(plan);
      painter.out('${report.prompt}y');
      final backup = BackupManager(demo.app).backup(preview.keys);
      EditApplier.write(preview);
      report.applied(
        edits: plan.edits.length,
        files: preview.length,
        backup: relativeForDisplay(backup, from: demo.app),
        temporaryKgpFlag: plan.temporaryKgpFlag,
      );
    });

    snapshot = await demo.detect();
    ctx = RuleContext(snapshot: snapshot, matrix: matrix);
    final plugins = _render((painter) {
      painter.header(packageVersion, matrix);
      PluginsReporter(
        painter,
      ).report(snapshot: snapshot, findings: runRules(pluginRules, ctx));
    });

    final log = File(
      p.join('test', 'fixtures', 'logs', 'ge002_kotlin_extension.log'),
    ).readAsStringSync();
    final explain = _render((painter) {
      painter.header(packageVersion, matrix);
      ExplainReporter(painter).report(Explainer(matrix: matrix).explain(log));
    });

    for (final (name, command, lines) in [
      ('check', 'android_build_doctor check', check),
      ('plugins', 'android_build_doctor plugins', plugins),
      (
        'explain',
        'flutter build apk 2>&1 | android_build_doctor explain -',
        explain,
      ),
      ('fix', 'android_build_doctor fix', fix),
    ]) {
      await _rasterise(
        _terminalSvg(lines, command: command),
        p.join(out.path, '$name.webp'),
        keepSvg: keepSvg,
      );
    }
    await _rasterise(
      _bannerSvg(),
      p.join('doc', 'banner.webp'),
      keepSvg: keepSvg,
    );
  } finally {
    demo.delete();
  }
}

/// What the reporters print through `draw`, in 24-bit colour.
List<String> _render(void Function(Painter painter) draw) {
  final lines = <String>[];
  draw(
    Painter(
      out: lines.add,
      ansi: Ansi(depth: ColorDepth.trueColor),
      width: _width,
    ),
  );
  return lines;
}

/// `my_app`: a Flutter 3.47 app that moved to AGP 9.1.0 but still applies
/// kotlin-android, on a Gradle too old for that AGP, with 40 plugins of which
/// three are not ready for built-in Kotlin.
class _DemoProject {
  _DemoProject(this.root);

  factory _DemoProject.create() {
    final demo = _DemoProject(
      Directory.systemTemp.createTempSync('abd_demo_').path,
    );
    demo._write();
    return demo;
  }

  final String root;

  String get app => p.join(root, 'my_app');

  Future<ProjectSnapshot> detect() async {
    final s = await ProjectDetector(
      run: noProcess,
      environment: const {},
    ).detect(app, scanPlugins: true);
    return s
        .copyWith(
          flutterVersion: const Detected('3.47.1'),
          dartVersion: const Detected('3.13.0'),
          javaVersion: const Detected(21),
          javaSource: 'Android Studio bundled JDK',
        )
        .withPlugins([
          for (final plugin in s.plugins)
            plugin.withLatestVersion(
              plugin.name == 'file_picker' ? '10.4.1' : plugin.version,
            ),
        ]);
  }

  void delete() => Directory(root).deleteSync(recursive: true);

  void _file(String path, String content) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  void _write() {
    String a(String rel) => p.join(app, rel);
    _file(a('pubspec.yaml'), 'name: my_app\nversion: 1.0.0+1\n');
    _file(a('android/settings.gradle.kts'), '''pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("\$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
''');
    _file(a('android/build.gradle.kts'), '''allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
''');
    _file(
      a('android/gradle.properties'),
      'org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G\n'
      'android.useAndroidX=true\n',
    );
    _file(
      a('android/gradle/wrapper/gradle-wrapper.properties'),
      'distributionBase=GRADLE_USER_HOME\n'
      'distributionPath=wrapper/dists\n'
      'zipStoreBase=GRADLE_USER_HOME\n'
      'zipStorePath=wrapper/dists\n'
      r'distributionUrl=https\://services.gradle.org/distributions/gradle-8.14-all.zip'
      '\n',
    );
    _file(a('android/app/build.gradle.kts'), '''plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.my_app"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.my_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
    }
}
''');
    _file(
      a('android/app/src/main/AndroidManifest.xml'),
      '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
      '</manifest>\n',
    );

    const kgpPlugin = '''apply plugin: "com.android.library"
apply plugin: "kotlin-android"

android {
    namespace = "com.example.plugin"
    compileSdk = 36
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
''';
    const noNamespacePlugin = '''apply plugin: "com.android.library"

android {
    compileSdk = 35
}
''';
    const readyPlugin = '''plugins {
    id("com.android.library")
}

android {
    namespace = "com.example.plugin"
    compileSdk = 36
}
''';
    final plugins = <(String, String, String, String)>[
      ('file_picker', '10.3.8', 'build.gradle', kgpPlugin),
      ('geocoding_android', '3.3.0', 'build.gradle', kgpPlugin),
      ('some_old_plugin', '0.2.1', 'build.gradle', noNamespacePlugin),
      for (var i = 1; i <= 37; i++)
        (
          'ready_plugin_${i.toString().padLeft(2, '0')}',
          '1.0.0',
          'build.gradle.kts',
          readyPlugin,
        ),
    ];
    final packages = <Map<String, Object?>>[];
    final lock = StringBuffer('packages:\n');
    for (final (name, version, file, gradle) in plugins) {
      final dir = p.join(root, 'pub-cache', '$name-$version');
      _file(p.join(dir, 'android', file), gradle);
      _file(p.join(dir, 'pubspec.yaml'), 'name: $name\nversion: $version\n');
      packages.add({
        'name': name,
        'rootUri': Directory(dir).uri.toString(),
        'packageUri': 'lib/',
      });
      lock
        ..writeln('  $name:')
        ..writeln('    dependency: "direct main"')
        ..writeln('    source: hosted')
        ..writeln('    version: "$version"');
    }
    packages.add({'name': 'my_app', 'rootUri': '../', 'packageUri': 'lib/'});
    _file(
      a('.dart_tool/package_config.json'),
      jsonEncode({'configVersion': 2, 'packages': packages}),
    );
    _file(a('pubspec.lock'), lock.toString());
  }
}

// ---------------------------------------------------------------------------
// ANSI -> SVG
// ---------------------------------------------------------------------------

const _font =
    "Menlo, 'SF Mono', Monaco, Consolas, 'DejaVu Sans Mono', monospace";
const _fontSize = 14.0;
const _cell = _fontSize * 0.6021; // Menlo's advance width.
const _lineHeight = 20.0;
const _padding = 24.0;
const _titleBar = 40.0;
const _margin = 56.0;

const _terminalBg = 0x0D1117;
const _terminalFg = 0xE6EDF3;
const _themeColors = [
  0x484F58, 0xFF7B72, 0x3FB950, 0xD29922, 0x58A6FF, 0xBC8CFF, 0x39C5CF, //
  0xB1BAC4, 0x6E7681, 0xFFA198, 0x56D364, 0xE3B341, 0x79C0FF, 0xD2A8FF,
  0x56D4DD, 0xFFFFFF,
];

class _Style {
  const _Style({this.fg, this.bg, this.bold = false, this.dim = false});

  final int? fg;
  final int? bg;
  final bool bold;
  final bool dim;

  _Style copy({
    int? Function()? fg,
    int? Function()? bg,
    bool? bold,
    bool? dim,
  }) => _Style(
    fg: fg == null ? this.fg : fg(),
    bg: bg == null ? this.bg : bg(),
    bold: bold ?? this.bold,
    dim: dim ?? this.dim,
  );

  int get color {
    final base = fg ?? _terminalFg;
    return dim ? _mix(base, _terminalBg, 0.5) : base;
  }

  @override
  bool operator ==(Object other) =>
      other is _Style &&
      other.fg == fg &&
      other.bg == bg &&
      other.bold == bold &&
      other.dim == dim;

  @override
  int get hashCode => Object.hash(fg, bg, bold, dim);
}

int _mix(int a, int b, double t) {
  int ch(int shift) {
    final x = (a >> shift) & 0xff, y = (b >> shift) & 0xff;
    return (x + (y - x) * t).round() & 0xff;
  }

  return (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

String _hex(int rgb) => '#${rgb.toRadixString(16).padLeft(6, '0')}';

int _xterm(int n) {
  if (n < 16) return _themeColors[n];
  if (n >= 232) {
    final v = 8 + 10 * (n - 232);
    return (v << 16) | (v << 8) | v;
  }
  const levels = [0, 95, 135, 175, 215, 255];
  final i = n - 16;
  return (levels[i ~/ 36] << 16) | (levels[(i ~/ 6) % 6] << 8) | levels[i % 6];
}

/// Splits one line of ANSI output into (text, style) cells.
List<(String, _Style)> _parse(String line) {
  final cells = <(String, _Style)>[];
  var style = const _Style();
  final sgr = RegExp(r'\x1B\[([0-9;]*)m');
  var i = 0;
  while (i < line.length) {
    final m = sgr.matchAsPrefix(line, i);
    if (m != null) {
      final codes = m.group(1)!.isEmpty
          ? [0]
          : m.group(1)!.split(';').map(int.parse).toList();
      for (var k = 0; k < codes.length; k++) {
        final c = codes[k];
        if (c == 0) {
          style = const _Style();
        } else if (c == 1) {
          style = style.copy(bold: true);
        } else if (c == 2) {
          style = style.copy(dim: true);
        } else if (c == 22) {
          style = style.copy(bold: false, dim: false);
        } else if (c == 39) {
          style = style.copy(fg: () => null);
        } else if (c == 49) {
          style = style.copy(bg: () => null);
        } else if (c >= 30 && c <= 37) {
          style = style.copy(fg: () => _themeColors[c - 30]);
        } else if (c >= 90 && c <= 97) {
          style = style.copy(fg: () => _themeColors[c - 82]);
        } else if (c >= 40 && c <= 47) {
          style = style.copy(bg: () => _themeColors[c - 40]);
        } else if (c >= 100 && c <= 107) {
          style = style.copy(bg: () => _themeColors[c - 92]);
        } else if ((c == 38 || c == 48) && k + 1 < codes.length) {
          int? rgb;
          if (codes[k + 1] == 2 && k + 4 < codes.length) {
            rgb = (codes[k + 2] << 16) | (codes[k + 3] << 8) | codes[k + 4];
            k += 4;
          } else if (codes[k + 1] == 5 && k + 2 < codes.length) {
            rgb = _xterm(codes[k + 2]);
            k += 2;
          }
          style = c == 38
              ? style.copy(fg: () => rgb)
              : style.copy(bg: () => rgb);
        }
      }
      i = m.end;
      continue;
    }
    final unit = line.codeUnitAt(i);
    final units = unit >= 0xD800 && unit <= 0xDBFF ? 2 : 1;
    cells.add((line.substring(i, i + units), style));
    i += units;
  }
  return cells;
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Plain ASCII renders reliably in Menlo at the cell width; anything else
/// is placed in its own cell so a fallback font cannot shift the line.
bool _plain(String ch) => ch.length == 1 && ch.codeUnitAt(0) < 0x7F;

/// Box-drawing characters are drawn as strokes that fill the whole cell, as
/// terminals do, so borders and meters join up across lines. Returns `null`
/// for any other character.
String? _boxPath(String ch, double x, double top, int color) {
  final left = x, right = x + _cell, cx = x + _cell / 2;
  final bottom = top + _lineHeight, cy = top + _lineHeight / 2;
  const r = 5.0;
  final String d;
  var stroke = 1.3;
  switch (ch) {
    case '─':
      d = 'M$left $cy H$right';
    case '━':
      d = 'M$left $cy H$right';
      stroke = 3.2;
    case '│':
      d = 'M$cx $top V$bottom';
    case '╭':
      d = 'M$right $cy H${cx + r} Q$cx $cy $cx ${cy + r} V$bottom';
    case '╮':
      d = 'M$left $cy H${cx - r} Q$cx $cy $cx ${cy + r} V$bottom';
    case '╰':
      d = 'M$right $cy H${cx + r} Q$cx $cy $cx ${cy - r} V$top';
    case '╯':
      d = 'M$left $cy H${cx - r} Q$cx $cy $cx ${cy - r} V$top';
    default:
      return null;
  }
  return '<path d="$d" fill="none" stroke="${_hex(color)}" '
      'stroke-width="$stroke" stroke-linecap="${stroke > 2 ? 'round' : 'butt'}"/>';
}

String _terminalSvg(List<String> output, {required String command}) {
  final lines = [
    '\x1B[38;2;61;220;132m❯\x1B[39m \x1B[1m$command\x1B[22m',
    '',
    ...output,
  ];
  // As wide as the longest line (URLs and paths are never shortened), so
  // nothing spills out of the window the way a terminal would soft-wrap it.
  final columns = lines.map(visibleWidth).fold(_width, math.max);
  final textWidth = columns * _cell;
  final windowWidth = textWidth + 2 * _padding;
  final windowHeight =
      _titleBar + _padding + lines.length * _lineHeight + _padding * 0.75;
  final width = windowWidth + 2 * _margin;
  final height = windowHeight + 2 * _margin;
  final x0 = _margin + _padding;
  final y0 = _margin + _titleBar + _padding * 0.6;

  final body = StringBuffer();
  for (var row = 0; row < lines.length; row++) {
    final cells = _parse(lines[row]);
    final top = y0 + row * _lineHeight;
    final baseline = top + _lineHeight * 0.72;
    var col = 0;
    var k = 0;
    while (k < cells.length) {
      final (ch, style) = cells[k];
      final x = x0 + col * _cell;
      final box = _boxPath(ch, x, top, style.color);
      if (box != null) {
        body.writeln(box);
        col++;
        k++;
        continue;
      }
      // A run of plain cells with the same style, or one special cell.
      var end = k + 1;
      var runCols = visibleWidth(ch);
      if (_plain(ch)) {
        while (end < cells.length &&
            cells[end].$2 == style &&
            _plain(cells[end].$1)) {
          runCols += visibleWidth(cells[end].$1);
          end++;
        }
      }
      final text = cells.sublist(k, end).map((c) => c.$1).join();
      final w = runCols * _cell;
      if (style.bg != null) {
        body.writeln(
          '<rect x="${x.toStringAsFixed(2)}" y="${(top + 1).toStringAsFixed(2)}" '
          'width="${w.toStringAsFixed(2)}" height="${(_lineHeight - 2).toStringAsFixed(2)}" '
          'rx="3" fill="${_hex(style.bg!)}"/>',
        );
      }
      if (text.trim().isNotEmpty) {
        body.writeln(
          '<text x="${x.toStringAsFixed(2)}" y="${baseline.toStringAsFixed(2)}" '
          'textLength="${w.toStringAsFixed(2)}" lengthAdjust="spacingAndGlyphs" '
          'fill="${_hex(style.color)}"'
          '${style.bold ? ' font-weight="bold"' : ''}>${_escape(text)}</text>',
        );
      }
      col += runCols;
      k = end;
    }
  }

  final wx = _margin, wy = _margin;
  final cx = wx + windowWidth / 2;
  return '''<svg xmlns="http://www.w3.org/2000/svg" width="${width.round()}" height="${height.round()}" viewBox="0 0 ${width.toStringAsFixed(2)} ${height.toStringAsFixed(2)}">
<defs>
  ${_glows(width, height)}
  <filter id="shadow" x="-10%" y="-10%" width="120%" height="130%">
    <feDropShadow dx="0" dy="16" stdDeviation="18" flood-color="#000000" flood-opacity="0.55"/>
  </filter>
</defs>
<rect width="100%" height="100%" fill="#07111f"/>
<rect width="100%" height="100%" fill="url(#glowA)"/>
<rect width="100%" height="100%" fill="url(#glowB)"/>
<rect x="$wx" y="$wy" width="${windowWidth.toStringAsFixed(2)}" height="${windowHeight.toStringAsFixed(2)}" rx="12" fill="${_hex(_terminalBg)}" filter="url(#shadow)"/>
<rect x="${wx + 0.5}" y="${wy + 0.5}" width="${(windowWidth - 1).toStringAsFixed(2)}" height="${(windowHeight - 1).toStringAsFixed(2)}" rx="12" fill="none" stroke="#ffffff" stroke-opacity="0.10"/>
<line x1="$wx" y1="${wy + _titleBar}" x2="${(wx + windowWidth).toStringAsFixed(2)}" y2="${wy + _titleBar}" stroke="#ffffff" stroke-opacity="0.06"/>
<circle cx="${wx + 20}" cy="${wy + _titleBar / 2}" r="6" fill="#ff5f57"/>
<circle cx="${wx + 40}" cy="${wy + _titleBar / 2}" r="6" fill="#febc2e"/>
<circle cx="${wx + 60}" cy="${wy + _titleBar / 2}" r="6" fill="#28c840"/>
<text x="${cx.toStringAsFixed(2)}" y="${wy + _titleBar / 2 + 4.5}" text-anchor="middle" font-family="'Helvetica Neue', Helvetica, Arial, sans-serif" font-size="13" fill="#8b949e">my_app — android_build_doctor</text>
<g font-family="$_font" font-size="$_fontSize" xml:space="preserve">
$body</g>
</svg>
''';
}

String _glows(double width, double height) {
  final r = math.max(width, height) * 0.75;
  return '''<radialGradient id="glowA" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(0 0) scale(${r.toStringAsFixed(1)})">
    <stop offset="0" stop-color="#0175C2" stop-opacity="0.55"/>
    <stop offset="1" stop-color="#0175C2" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="glowB" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(${width.toStringAsFixed(1)} ${height.toStringAsFixed(1)}) scale(${r.toStringAsFixed(1)})">
    <stop offset="0" stop-color="#3DDC84" stop-opacity="0.30"/>
    <stop offset="1" stop-color="#3DDC84" stop-opacity="0"/>
  </radialGradient>''';
}

// ---------------------------------------------------------------------------
// Banner
// ---------------------------------------------------------------------------

String _bannerSvg() {
  const width = 1280.0, height = 400.0;
  const chips = ['check', 'plugins', 'explain', 'fix'];
  const chipFont = 18.0, chipHeight = 38.0, chipGap = 12.0;
  const chipPad = 20.0;
  final chip = StringBuffer();
  var x = 412.0;
  for (final c in chips) {
    final w = c.length * chipFont * 0.6021 + 2 * chipPad;
    chip.writeln(
      '<rect x="$x" y="270" width="${w.toStringAsFixed(1)}" height="$chipHeight" rx="${chipHeight / 2}" '
      'fill="#ffffff" fill-opacity="0.06" stroke="#ffffff" stroke-opacity="0.14"/>',
    );
    chip.writeln(
      '<text x="${(x + chipPad).toStringAsFixed(1)}" y="295" font-family="$_font" '
      'font-size="$chipFont" fill="#e6edf3">$c</text>',
    );
    x += w + chipGap;
  }
  return '''<svg xmlns="http://www.w3.org/2000/svg" width="${width.round()}" height="${height.round()}" viewBox="0 0 $width $height">
<defs>
  ${_glows(width, height)}
  <linearGradient id="tile" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#0175C2"/>
    <stop offset="0.55" stop-color="#13B9FD"/>
    <stop offset="1" stop-color="#3DDC84"/>
  </linearGradient>
  <filter id="shadow" x="-30%" y="-30%" width="160%" height="170%">
    <feDropShadow dx="0" dy="14" stdDeviation="16" flood-color="#000000" flood-opacity="0.5"/>
  </filter>
</defs>
<rect width="100%" height="100%" fill="#07111f"/>
<rect width="100%" height="100%" fill="url(#glowA)"/>
<rect width="100%" height="100%" fill="url(#glowB)"/>
<g transform="translate(236 134)" filter="url(#shadow)">
  <rect width="136" height="136" rx="34" fill="url(#tile)"/>
  <rect x="1" y="1" width="134" height="134" rx="33" fill="none" stroke="#ffffff" stroke-opacity="0.25" stroke-width="2"/>
  <polyline points="22,74 46,74 56,50 70,100 84,58 94,74 114,74" fill="none" stroke="#ffffff" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
</g>
<text x="410" y="196" font-family="$_font" font-size="54" font-weight="bold" fill="#ffffff">android_build_doctor</text>
<text x="412" y="242" font-family="'Helvetica Neue', Helvetica, Arial, sans-serif" font-size="27" fill="#a9b8cc">The AGP 9 era build doctor for Flutter</text>
$chip</svg>
''';
}

// ---------------------------------------------------------------------------

Future<void> _rasterise(
  String svg,
  String webpPath, {
  required bool keepSvg,
}) async {
  final svgPath = p.setExtension(webpPath, '.svg');
  final pngPath = p.setExtension(webpPath, '.png');
  File(svgPath).writeAsStringSync(svg);
  for (final (tool, args) in [
    (
      'rsvg-convert',
      ['--zoom=2', '--format=png', '--output=$pngPath', svgPath],
    ),
    ('cwebp', ['-quiet', '-lossless', '-z', '9', pngPath, '-o', webpPath]),
  ]) {
    final r = await Process.run(tool, args);
    if (r.exitCode != 0) {
      stderr.writeln('$tool failed for $webpPath: ${r.stderr}');
      exit(1);
    }
  }
  File(pngPath).deleteSync();
  if (!keepSvg) File(svgPath).deleteSync();
  stdout.writeln('wrote $webpPath');
}
