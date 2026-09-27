[![android_build_doctor: the AGP 9 era build doctor for Flutter](https://raw.githubusercontent.com/zainulabdn/android_build_doctor/main/doc/banner.webp)](https://pub.dev/packages/android_build_doctor)

[![pub package](https://img.shields.io/pub/v/android_build_doctor.svg?label=pub.dev&color=2a78d6)](https://pub.dev/packages/android_build_doctor)
[![pub points](https://img.shields.io/pub/points/android_build_doctor?color=0ca30c)](https://pub.dev/packages/android_build_doctor/score)
[![CI](https://github.com/zainulabdn/android_build_doctor/actions/workflows/ci.yml/badge.svg)](https://github.com/zainulabdn/android_build_doctor/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://github.com/zainulabdn/android_build_doctor/blob/main/LICENSE)

**The AGP 9 era build doctor for Flutter.** It checks your app *and every
plugin you depend on*, tells you exactly who is blocking your upgrade,
explains Gradle errors in plain language, and fixes what it safely can.

```bash
dart pub global activate android_build_doctor
cd my_flutter_app
android_build_doctor check
```

![android_build_doctor check: a toolchain panel with Java, Gradle, AGP, Kotlin, built-in Kotlin and SDK levels, each problem with its file, line and fix, and a summary card with the next command to run](https://raw.githubusercontent.com/zainulabdn/android_build_doctor/main/doc/screenshots/check.webp)

## Why this exists

Flutter's own survey names **upgrade pain** as the number one frustration:
developers lose hours guessing which Flutter, Dart, Gradle, Kotlin, AGP and
Java versions work together. AGP 9 made it worse. AGP 9 has Kotlin built in,
so any app or plugin that still applies `kotlin-android` fails with

```
Cannot add extension with name 'kotlin', as there is an extension already registered with that name
```

and you cannot tell from the error whether the problem is your files or one of
your forty plugins. This tool can.

## Why not `flutter analyze --suggestions`?

| | `flutter analyze --suggestions` | Android Studio AGP Upgrade Assistant | `android_build_doctor` |
|---|---|---|---|
| Checks your app's Java / Gradle / AGP | yes | yes | yes |
| Checks **every plugin** for AGP 9 / built-in Kotlin blockers | no | no | **yes** |
| Explains a failed build log | no | no | **yes** |
| Fixes versions, `jcenter()`, missing `namespace` | no | partially | **yes**, with diff, backup and `restore` |
| Plans an upgrade to a target Flutter version | no | no | **yes** (`--target`) |
| Flutter-aware, works from VS Code / CI | yes | no | yes |
| Compatibility data updated without a new release | n/a | n/a | **yes** (fetched from GitHub, bundled fallback) |

`flutter analyze --suggestions` is good; run both. This tool focuses on what it
does not do: plugins, explanations, fixes and CI.

## Quick start

Install it globally (make sure `~/.pub-cache/bin` is on your `PATH`):

```bash
dart pub global activate android_build_doctor
```

Or add it to your project as a dev dependency:

```bash
flutter pub add --dev android_build_doctor
dart run android_build_doctor check
```

## See who is blocking AGP 9

`android_build_doctor plugins` reads every plugin in your dependency tree and
shows how many are ready for AGP 9 with built-in Kotlin, which ones block you,
and whether a newer release is on pub.dev. Plugins with errors come first.

![android_build_doctor plugins: an AGP 9 readiness meter at 38 of 40 plugins, the two blockers, and each problem plugin with its findings](https://raw.githubusercontent.com/zainulabdn/android_build_doctor/main/doc/screenshots/plugins.webp)

## Understand a failed build

Pipe a failed build into `explain`. It names the pattern, the plugin or module
that caused it, why it happened, and the steps to fix it.

```bash
flutter build apk 2>&1 | android_build_doctor explain -
```

![android_build_doctor explain: the Kotlin plugin applied twice on AGP 9, blamed on file_picker 10.3.8, with the cause and four numbered fix steps](https://raw.githubusercontent.com/zainulabdn/android_build_doctor/main/doc/screenshots/explain.webp)

## Fix it, safely

`fix` shows its plan and a line-numbered diff for every file, asks before
writing, backs every file up first, and `restore` undoes it.

![android_build_doctor fix: a plan of three edits, the diff for each file, advice about plugins, and the applied result with the backup location](https://raw.githubusercontent.com/zainulabdn/android_build_doctor/main/doc/screenshots/fix.webp)

## Commands

| Command | What it does |
|---|---|
| `android_build_doctor check` | Read every version, compare with the matrix, print a report. Changes nothing. |
| `android_build_doctor plugins` | Scan every plugin in the dependency tree for AGP 9 / built-in Kotlin blockers, missing namespaces, `jcenter()` and old settings. Shows the readiness meter. |
| `android_build_doctor fix` | Apply safe fixes. Shows the plan and a diff, asks `Apply these changes? (y/N)`, always backs files up first. |
| `android_build_doctor fix --dry-run` | Show the plan and the diff only. |
| `android_build_doctor fix --yes --verify` | Apply without asking, then run `flutter clean && flutter build apk --debug`. |
| `android_build_doctor restore` | Undo the last `fix` from `android/.android_build_doctor_backup/`. |
| `android_build_doctor explain <log>` | Explain a failed build log. `-` reads stdin: `flutter build apk 2>&1 \| android_build_doctor explain -` |
| `android_build_doctor matrix` | Print the compatibility matrix in use, its source and date. |

Global flags:

| Flag | Meaning |
|---|---|
| `--json` | Machine-readable output for CI and AI agents. |
| `--ci` | No prompts, no colours, ASCII symbols, exit code 1 when errors are found. |
| `--offline` | Skip the remote matrix fetch and pub.dev lookups. |
| `--target <flutterVersion>` | Upgrade planner: "what must change to run on Flutter X?" |
| `--flutter-version <x.y.z>` | Assume this Flutter version instead of running `flutter --version`. |
| `--project <dir>` | Project directory (default: current). |
| `--verbose` / `-v` | Show docs links, detection notes and matrix loading details. |
| `--no-color` | Plain text, no colours. |

The matrix cache lives in `~/.android_build_doctor/`. Set
`ANDROID_BUILD_DOCTOR_CACHE_DIR` to relocate it, which is useful in CI where
you may want it inside the workspace cache.

Exit codes: `0` OK or warnings only, `1` errors found, `2` tool failure (not a Flutter project, bad input).

### What `check` looks for

| ID | Severity | Rule |
|---|---|---|
| GD001 | error | Java below the minimum required by Flutter, AGP or Gradle |
| GD002 | error | Gradle below the minimum required by the AGP version |
| GD003 | error | Java too new for the Gradle version (`Unsupported class file major version`) |
| GD004 | warning | AGP / KGP / Gradle older than what your Flutter release was verified with |
| GD005 | error | AGP 9 + app applies `kotlin-android` + `android.builtInKotlin` not `false` |
| GD006 | warning | Legacy KGP kept alive with `android.builtInKotlin=false` (support will be removed) |
| GD007 | error | `android.builtInKotlin=true` but plugins still apply KGP |
| GD008 | warning | Imperative `apply from: flutter.gradle` / `app_plugin_loader.gradle` (deprecated) |
| GD009 | error | Missing `namespace` in `android/app/build.gradle(.kts)` |
| GD010 | warning | `sourceCompatibility` and Kotlin `jvmTarget` differ |
| GD011 | info | Hard-coded compileSdk / targetSdk / minSdk instead of `flutter.*` variables |
| GD012 | warning | minSdk below the Flutter default |
| GD013 | warning | `jcenter()` still present |
| GD014 | info | Project created with a much older Flutter; consider regenerating `android/` |
| GD015 | warning | CI `java-version` differs from the local Java |
| GD016 | error | Gradle / AGP / KGP below the hard minimum Flutter's Gradle plugin enforces |

### What `plugins` looks for

| ID | Severity | Rule |
|---|---|---|
| GP001 | error / warning | Plugin applies `kotlin-android` (blocks built-in Kotlin; an error once `builtInKotlin=true`) |
| GP002 | error | Plugin has no `namespace` (breaks on AGP 8+) |
| GP003 | warning | Plugin uses `jcenter()` |
| GP004 | warning | Plugin hard-codes an old compileSdk, Java 8, or an old KGP classpath |
| GP005 | info | A newer version of the plugin exists on pub.dev |

Plugins are never edited. For plugin problems the tool prints advice: upgrade,
open an issue with the author (the migration guide has an issue template), or
keep `android.builtInKotlin=false` until they are ready.

### What `explain` understands

GE001 unsupported class file version, GE002 duplicate `kotlin` extension (AGP 9),
GE003 minimum Gradle for AGP, GE004 Kotlin too old for Flutter, GE005
incompatible Kotlin metadata, GE006 namespace not specified, GE007 inconsistent
JVM targets, GE008 minSdk too low for a library, GE009 compileSdk too low for a
dependency, GE010 JCenter resolution failure, GE011/GE012 Flutter's own
"lower than minimum" / "will soon be dropped" messages, GE013 imperative apply
deprecation, GE014 AGP version not found, GE015 KGP too old for AGP. When
nothing matches, it prints the cleaned `What went wrong` block and names the
module involved.

## How `fix` decides

1. Targets are the versions your Flutter release was **verified** with (its
   project template). Nothing is ever downgraded.
2. If the plugin audit finds plugins that still apply the Kotlin Gradle Plugin,
   and you are not on AGP 9 yet, the plan stays on the newest AGP 8 combination
   Flutter shipped instead of pushing you to AGP 9. If plugins could not be
   scanned (`.dart_tool` missing), the same conservative choice is made.
3. If you are already on AGP 9 and something still applies KGP, the plan adds
   `android.builtInKotlin=false` as a clearly labelled stop-gap (Flutter 3.44+).
4. Gradle is raised to whatever the target AGP and your local JDK need.
5. `jcenter()` becomes `mavenCentral()` (or is removed when Maven Central is
   already listed) and a missing `namespace` is added from `AndroidManifest.xml`.

Safety: every touched file is copied to `android/.android_build_doctor_backup/<timestamp>/`
first, the diff is shown, edits change only the exact lines involved (comments,
quotes and indentation elsewhere are untouched), a dirty git tree triggers a
warning, and `android_build_doctor restore` undoes the last run.

## Output that reads well everywhere

- **Light and dark terminals.** The status colours were checked with the WCAG
  contrast formula against white, Solarized Light and four dark themes, and keep
  at least 3:1 on all of them. Text stays in your terminal's own colours; colour
  only marks symbols, badges, borders and meters, always next to a symbol or a
  word.
- **Your terminal's colour depth.** 24-bit, 256 and 16 colours are detected from
  `COLORTERM`, `TERM`, `TERM_PROGRAM` and `WT_SESSION`. `NO_COLOR` turns colour
  off and `FORCE_COLOR` (`1`, `2`, `3`) turns it on, for example when piping into
  `less -R`.
- **Logs stay clean.** `--ci` and Windows consoles get plain ASCII. The progress
  spinner only appears on an interactive terminal and never in `--json` output.

## CI usage

```yaml
# .github/workflows/android.yml
- uses: dart-lang/setup-dart@v1
- run: dart pub global activate android_build_doctor
- run: android_build_doctor check --ci          # exit 1 on errors
- run: android_build_doctor plugins --ci --json > plugin-report.json
- run: flutter build apk --debug 2>&1 | tee build.log || android_build_doctor explain build.log
```

`--json` output has the shape `{ "versions": {...}, "findings": [{ "id", "severity", "file", "line", "message", "fix", "docs" }], "summary": {...} }`.
`fix --json` prints one document with the plan, the diffs and, with `--yes`,
the backup location; without `--yes` it applies nothing.

## The compatibility matrix

All version knowledge lives in [`data/matrix.yaml`](https://github.com/zainulabdn/android_build_doctor/blob/main/data/matrix.yaml), not in
code. Every number cites its source (Flutter's release posts and the
`flutter_tools` source at each release tag, Gradle's compatibility page, AGP
release notes). On each run the tool fetches the latest copy from this
repository (3 second timeout, cached for 24 hours) and falls back to the
bundled copy, so a new Flutter release only needs a data update, not a new
package version. The report header always shows the matrix date and source.

Spotted a wrong entry? Please [open an issue](https://github.com/zainulabdn/android_build_doctor/issues).

## For AI coding agents

The package ships a skill in `skills/` that tells agents (Claude Code, Gemini
CLI, Cursor and friends) to run `android_build_doctor explain` on a failed
Android build log and `android_build_doctor check --json` before touching
Gradle files. Install it with `dart run skills@ get`.

## Contributing: add an error pattern in 5 minutes

Patterns live in [`data/errors.yaml`](https://github.com/zainulabdn/android_build_doctor/blob/main/data/errors.yaml). Add an entry:

```yaml
  - id: GE016
    regex: 'the distinctive text from the log, with (capture) groups'
    title: One line, what happened
    cause: Plain language. Use {1} for capture groups.
    fix:
      - Step one.
      - Step two.
    docs: https://link.to/docs
    severity: warning   # optional; only for notices from a build that succeeded
```

Then drop a real log in `test/fixtures/logs/ge016_something.log`, run
`dart run tool/embed_data.dart` and `dart test`. The test suite checks that
every pattern matches its fixture and nothing else.

The screenshots above are the real output, rendered by
`dart run tool/screenshots.dart` (needs `rsvg-convert` and `cwebp`: `brew install librsvg webp`).

## Using it as a library

```dart
import 'package:android_build_doctor/android_build_doctor.dart';

Future<void> main() async {
  final matrix = await MatrixLoader().load();
  final snapshot = await ProjectDetector().detect('.', scanPlugins: true);
  final ctx = RuleContext(snapshot: snapshot, matrix: matrix);
  for (final finding in runRules(projectRules, ctx)) {
    print('${finding.id} ${finding.severity.label}: ${finding.message}');
  }
}
```

## Roadmap

- `android_build_doctor.yaml` config file to ignore rules per project
- GitHub Action that comments findings on pull requests
- MCP server mode so agents can call `check` / `explain` directly
- iOS counterpart (CocoaPods to Swift Package Manager checks)

## License

MIT
