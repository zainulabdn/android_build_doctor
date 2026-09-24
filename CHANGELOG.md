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
