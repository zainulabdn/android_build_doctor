# android_build_doctor

**The AGP 9 era build doctor for Flutter.** It checks your app *and every
plugin you depend on*, tells you exactly who is blocking your upgrade,
explains Gradle errors in plain language, and fixes what it safely can.

```
$ android_build_doctor check

android_build_doctor 0.1.0 • matrix 2026-09-24 (remote)

Project: my_app   Flutter 3.47.1 • Dart 3.13.0

  Java            21       ✓  (min 17)
  Gradle          8.7      ✗  AGP 9.1.0 needs Gradle >= 9.3.1, but the wrapper uses Gradle 8.7.  android/gradle/wrapper/gradle-wrapper.properties:5
  AGP             9.1.0    ✓  (verified 9.1.0)
  Kotlin          2.1.0    ⚠  Kotlin Gradle Plugin 2.1.0 is older than the 2.4.0 that Flutter 3.47 was verified with.  android/settings.gradle.kts:24
  Built-in Kotlin unset    ✗  AGP 9.1.0 has Kotlin built in, but android/app applies kotlin-android  android/app/build.gradle.kts:4
  SDK levels               ✓  compile flutter.compileSdkVersion  target flutter.targetSdkVersion  min flutter.minSdkVersion

✗ 2 errors  ⚠ 1 warning

Run `android_build_doctor fix` to fix 3 of 3 automatically.
Run `android_build_doctor plugins` to check if your plugins are AGP 9 ready.
```

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

```bash
dart pub global activate android_build_doctor
cd my_flutter_app
android_build_doctor check
```

Or as a dev dependency:

```bash
flutter pub add --dev android_build_doctor
dart run android_build_doctor check
```

## The plugin readiness report

```
$ android_build_doctor plugins

android_build_doctor 0.1.0 • matrix 2026-09-24 (remote)

Project: my_app   AGP 9.1.0 • android.builtInKotlin=false
40 plugin(s) with an Android module found in .dart_tool/package_config.json

⚠ file_picker 10.3.8  (latest 10.4.1)
    GP001 file_picker 10.3.8 still applies the Kotlin Gradle Plugin. It blocks enabling built-in Kotlin (AGP 9).
    GP005 file_picker 10.3.8 -> 10.4.1 is available on pub.dev.
⚠ geocoding_android 3.3.0
    GP001 geocoding_android 3.3.0 still applies the Kotlin Gradle Plugin. It blocks enabling built-in Kotlin (AGP 9).
✗ some_old_plugin 0.2.1
    GP002 some_old_plugin 0.2.1 declares no namespace in its build.gradle. AGP 8+ fails with "Namespace not specified".

✗ 1 error  ⚠ 2 warnings

AGP 9 + built-in Kotlin readiness: 37/40 plugins ready. Blockers: file_picker, geocoding_android, some_old_plugin.
```

## Commands

| Command | What it does |
|---|---|
| `android_build_doctor check` | Read every version, compare with the matrix, print a report. Changes nothing. |
| `android_build_doctor plugins` | Scan every plugin in the dependency tree for AGP 9 / built-in Kotlin blockers, missing namespaces, `jcenter()` and old settings. Ends with the readiness verdict. |
| `android_build_doctor fix` | Apply safe fixes. Shows a unified diff, asks `Apply these changes? (y/N)`, always backs files up first. |
| `android_build_doctor fix --dry-run` | Show the diff only. |
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

## The compatibility matrix

All version knowledge lives in [`data/matrix.yaml`](data/matrix.yaml), not in
code. Every number cites its source (Flutter's release posts and the
`flutter_tools` source at each release tag, Gradle's compatibility page, AGP
release notes). On each run the tool fetches the latest copy from this
repository (3 second timeout, cached for 24 hours) and falls back to the
bundled copy, so a new Flutter release only needs a data update, not a new
package version. The report footer always shows the matrix date and source.

Spotted a wrong entry? Please [open an issue](https://github.com/zainulabdn/android_build_doctor/issues).

## For AI coding agents

The package ships a skill in `skills/` that tells agents (Claude Code, Gemini
CLI, Cursor and friends) to run `android_build_doctor explain` on a failed
Android build log and `android_build_doctor check --json` before touching
Gradle files. Install it with `dart run skills@ get`.

## Contributing: add an error pattern in 5 minutes

Patterns live in [`data/errors.yaml`](data/errors.yaml). Add an entry:

```yaml
  - id: GE016
    regex: 'the distinctive text from the log, with (capture) groups'
    title: One line, what happened
    cause: Plain language. Use {1} for capture groups.
    fix:
      - Step one.
      - Step two.
    docs: https://link.to/docs
```

Then drop a real log in `test/fixtures/logs/ge016_something.log`, run
`dart run tool/embed_data.dart` and `dart test`. The test suite checks that
every pattern matches its fixture and nothing else.

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
