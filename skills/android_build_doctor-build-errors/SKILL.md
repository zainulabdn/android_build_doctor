---
name: android_build_doctor-build-errors
description: >-
  Use when a Flutter Android (Gradle) build fails, when a user asks about
  Gradle / AGP / Kotlin / Java version compatibility, when upgrading Flutter
  breaks the Android build, or before editing any file under android/. Runs
  android_build_doctor to diagnose, audit plugins and apply safe fixes.
---

# Diagnosing Flutter Android build failures with android_build_doctor

## When to use

- `flutter build apk` / `flutter run` on Android fails with a Gradle error.
- The user upgraded Flutter, Android Studio, the JDK, AGP or Kotlin and the
  Android build broke.
- Errors mention `Unsupported class file major version`, `Cannot add extension
  with name 'kotlin'`, `Namespace not specified`, `Minimum supported Gradle
  version`, `is lower than Flutter's minimum supported version`, or
  `Inconsistent JVM-target compatibility`.
- You are about to change versions in `android/settings.gradle(.kts)`,
  `android/build.gradle(.kts)`, `android/app/build.gradle(.kts)`,
  `android/gradle.properties` or `gradle-wrapper.properties`.

## Guidelines

1. Install once: `dart pub global activate android_build_doctor`
   (or `dart run android_build_doctor ...` if it is a dev dependency).
2. **Explain the log first.** Save the failed build output and run
   `android_build_doctor explain <logfile>` (or pipe it:
   `flutter build apk 2>&1 | android_build_doctor explain -`). It names the
   pattern (GE###), the cause, the fix and the culprit plugin.
3. **Get the facts before editing.** Run
   `android_build_doctor check --json` from the project root and read
   `findings[]` (each has `id`, `severity`, `file`, `line`, `message`, `fix`).
   Do not guess version numbers; the `versions` and `release` objects contain
   the verified Gradle / AGP / Kotlin / Java versions for the user's Flutter.
4. **Plugins are usually the blocker on AGP 9.** Run
   `android_build_doctor plugins --json`. If `verdict.blockers` is non-empty,
   do NOT edit files in the pub cache. Instead: upgrade those plugins, or keep
   `android.builtInKotlin=false` in `android/gradle.properties` (Flutter 3.44+),
   and tell the user which plugins need an upstream fix.
5. **Prefer the tool's fixes over hand edits.** `android_build_doctor fix
   --dry-run` shows the exact diff; `android_build_doctor fix --yes` applies it
   with a backup (`android_build_doctor restore` undoes it). Then verify with
   `flutter clean && flutter build apk --debug`.
6. Never downgrade Gradle / AGP / Kotlin to "make it work"; use the versions the
   tool reports as verified for the user's Flutter release.
7. For upgrade planning: `android_build_doctor --target <flutterVersion> check`.

## Examples

```bash
flutter build apk --debug 2>&1 | tee /tmp/build.log
android_build_doctor explain /tmp/build.log
android_build_doctor check --json > /tmp/doctor.json
android_build_doctor plugins --json > /tmp/plugins.json
android_build_doctor fix --dry-run
```

Exit codes: 0 = OK or warnings, 1 = errors found (or explain matched), 2 = tool
failure (not a Flutter project, missing `.dart_tool`: run `flutter pub get`).
