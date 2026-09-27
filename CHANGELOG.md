## 0.2.0

A redesigned terminal experience.

- Every command has a new look: titled rounded panels, `ERROR` / `WARN` /
  `INFO` badges, a toolchain panel in `check`, an AGP 9 readiness meter in
  `plugins`, culprit, cause and numbered fix steps in `explain`, and a plan
  plus line-numbered diffs in `fix`. Each report ends with a card that sums
  it up and says what to run next.
- Colours were picked by measuring contrast: every status colour keeps at
  least 3:1 on white, Solarized Light and four dark themes, and a test guards
  it. Text stays in the terminal's own colours.
- 24-bit, 256- and 16-colour terminals are detected (`COLORTERM`, `TERM`,
  `TERM_PROGRAM`, `WT_SESSION`); `NO_COLOR` and `FORCE_COLOR` are honoured.
  `--ci` and Windows consoles still get plain ASCII.
- A spinner shows progress while Flutter, the matrix and pub.dev are queried,
  on interactive terminals only.
- `explain` marks notices from a build that succeeded (GE012, GE013) as
  warnings. `errors.yaml` entries accept an optional `severity`, and
  `explain --json` includes it.
- Fixed: `fix --json` now prints exactly one JSON document. It applies changes
  only with `--yes` (it cannot ask), reports the backup and `--verify` result
  in the same document, and its diffs contain no colour codes.
- README and pub.dev screenshots, rendered from the real output by
  `tool/screenshots.dart`.
- Library: new `Painter`, `Glyphs`, `Tones`, `ColorDepth` and the
  `PluginsReporter`, `ExplainReporter`, `FixReporter` and `MatrixReporter`
  views; `Ansi` gained colour depths and `ConsoleReporter` a `width`.

## 0.1.0

Initial release.

- `check`: reads Flutter, Dart, Java, Gradle, AGP, Kotlin, SDK levels, JVM
  targets, namespace and plugin-apply style from Groovy and Kotlin DSL files,
  legacy `buildscript` classpaths and version catalogs; every value carries its
  file and line. Rules GD001-GD016.
- `plugins`: scans every Android plugin in `.dart_tool/package_config.json` for
  AGP 9 / built-in Kotlin blockers, missing namespaces, `jcenter()` and stale
  settings (GP001-GP005, with pub.dev latest-version lookups) and prints the
  readiness verdict.
- `explain`: plain-language explanations for 15 Gradle failure patterns
  (`data/errors.yaml`), culprit-plugin extraction, stdin support.
- `fix` / `fix --dry-run` / `--yes` / `--verify` and `restore`: minimal line
  edits with unified diff, confirmation, timestamped backups, never-downgrade
  and plugin-aware AGP targeting.
- `matrix`: shows the compatibility data in use; remote fetch with 24 hour
  cache and bundled fallback; `--offline`.
- `--json`, `--ci`, `--target` upgrade planner, `--flutter-version`.
- Agent skill in `skills/`.
