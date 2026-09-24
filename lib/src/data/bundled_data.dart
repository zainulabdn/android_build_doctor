// GENERATED FILE. Do not edit by hand.
// Regenerate with: dart run tool/embed_data.dart
// ignore_for_file: lines_longer_than_80_chars

/// Contents of `data/matrix.yaml` at build time.
const String bundledMatrixYaml = r'''
# Compatibility matrix for android_build_doctor.
#
# This is DATA, not code. Every number here was taken from the sources listed
# below on the `updated` date. Rows that were derived rather than read verbatim
# carry a "# derived:" note; anything unconfirmed carries "# TODO verify".
# If you find a wrong entry, please open an issue or a pull request:
#   https://github.com/zainulabdn/android_build_doctor/issues
#
# Flutter "verified" rows are the versions Flutter's own project template ships
# with for that release (packages/flutter_tools/lib/src/android/gradle_utils.dart
# at the release tag). "minimums" and "warn_below" are the thresholds Flutter's
# Gradle plugin enforces at build time (DependencyVersionChecker.kt at the tag):
# below "minimums" the Flutter Gradle plugin fails the build, below
# "warn_below" it prints a deprecation warning.

schema_version: 1
updated: 2026-09-24
latest_flutter: "3.47"

sources:
  - https://flutter.dev/blog/whats-new-in-flutter-3-47
  - https://flutter.dev/blog/whats-new-in-flutter-3-44
  - https://flutter.dev/blog/whats-new-in-flutter-3-38
  - https://github.com/flutter/flutter/blob/3.47.0/packages/flutter_tools/lib/src/android/gradle_utils.dart
  - https://github.com/flutter/flutter/blob/3.47.0/packages/flutter_tools/gradle/src/main/kotlin/DependencyVersionChecker.kt
  - https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin
  - https://docs.gradle.org/current/userguide/compatibility.html
  - https://developer.android.com/build/releases/gradle-plugin
  - https://developer.android.com/build/releases/past-releases

flutter:
  "3.47":
    verified: { java: "17", kgp: "2.4.0", agp: "9.1.0", gradle: "9.3.1" }
    minimums: { java: "17", gradle: "8.14.0", agp: "8.11.1", kgp: "2.2.20" }
    warn_below: { gradle: "9.1.0", agp: "9.0.1", kgp: "2.3.20" }
    max_known: { agp: "9.2", gradle: "9.3.1", kgp: "2.4.0" }
    defaults: { compileSdk: 36, targetSdk: 36, minSdk: 24, ndk: "28.2.13676358" }
    builtin_kotlin:
      supported: true        # android.builtInKotlin=true allowed once app + plugins migrated
      legacy_kgp_flag: true  # android.builtInKotlin=false still works
    # Newest AGP 8 combination that Flutter itself shipped (the 3.41 template)
    # and that satisfies this release's "minimums". Used by `fix` when plugins
    # are not ready for AGP 9.
    agp8_combo: { agp: "8.11.1", gradle: "8.14", kgp: "2.2.20" }
  "3.44":
    verified: { java: "17", kgp: "2.3.20", agp: "9.0.1", gradle: "9.1.0" }
    minimums: { java: "17", gradle: "8.7.0", agp: "8.6.0", kgp: "2.0.0" }
    warn_below: { gradle: "8.14.0", agp: "8.11.1", kgp: "2.2.20" }
    max_known: { agp: "9.1", gradle: "9.3.1", kgp: "2.3.20" }
    defaults: { compileSdk: 36, targetSdk: 36, minSdk: 24, ndk: "28.2.13676358" }
    builtin_kotlin:
      supported: false       # builtInKotlin=true not supported until 3.47
      legacy_kgp_flag: true  # 3.44 introduced android.builtInKotlin=false
    agp8_combo: { agp: "8.11.1", gradle: "8.14", kgp: "2.2.20" }
  "3.41":
    verified: { java: "17", kgp: "2.2.20", agp: "8.11.1", gradle: "8.14" }
    minimums: { java: "17", gradle: "8.3.0", agp: "8.1.1", kgp: "1.8.10" }
    warn_below: { gradle: "8.7.0", agp: "8.6.0", kgp: "2.1.0" }
    max_known: { agp: "9.0", gradle: "9.1.0", kgp: "2.2.20" }
    # Flutter 3.41 release post: "Do not update your Flutter app for Android to AGP 9".
    max_recommended_agp: "8"
    defaults: { compileSdk: 36, targetSdk: 36, minSdk: 24, ndk: "28.2.13676358" }
    builtin_kotlin: { supported: false, legacy_kgp_flag: false }
  "3.38":
    verified: { java: "17", kgp: "2.2.20", agp: "8.11.1", gradle: "8.14" }
    minimums: { java: "17", gradle: "8.3.0", agp: "8.1.1", kgp: "1.8.10" }
    warn_below: { gradle: "8.7.0", agp: "8.6.0", kgp: "2.1.0" }
    max_known: { agp: "9.0", gradle: "9.1.0", kgp: "2.2.20" }
    max_recommended_agp: "8"
    defaults: { compileSdk: 36, targetSdk: 36, minSdk: 24, ndk: "28.2.13676358" }
    builtin_kotlin: { supported: false, legacy_kgp_flag: false }
  "3.35":
    verified: { java: "17", kgp: "2.1.0", agp: "8.9.1", gradle: "8.12" }
    minimums: { java: "11", gradle: "8.3.0", agp: "8.1.1", kgp: "1.8.10" }
    warn_below: { java: "17", gradle: "8.7.0", agp: "8.6.0", kgp: "2.1.0" }
    max_known: { agp: "8.9.1", gradle: "8.12", kgp: "2.1.20" }
    defaults: { compileSdk: 36, targetSdk: 36, minSdk: 24, ndk: "27.0.12077973" }
    builtin_kotlin: { supported: false, legacy_kgp_flag: false }
  "3.32":
    # verified.java derived: the template AGP (8.7.3) requires JDK 17.
    verified: { java: "17", kgp: "2.1.0", agp: "8.7.3", gradle: "8.12" }
    minimums: { gradle: "7.0.2", agp: "7.0.0", kgp: "1.7.0" }
    warn_below: { java: "11", gradle: "7.4.2", agp: "8.3.0", kgp: "1.8.10" }
    max_known: { agp: "8.7.3", gradle: "8.12" }
    defaults: { compileSdk: 35, targetSdk: 35, minSdk: 21, ndk: "26.1.10909125" }
    builtin_kotlin: { supported: false, legacy_kgp_flag: false }
  "3.29":
    verified: { java: "17", kgp: "1.8.22", agp: "8.7.0", gradle: "8.10.2" }  # java derived from AGP 8.x
    # derived: 3.27 and 3.32 enforce the same thresholds, so 3.29 does too.
    minimums: { gradle: "7.0.2", agp: "7.0.0", kgp: "1.7.0" }
    warn_below: { java: "11", gradle: "7.1.0", agp: "7.0.1", kgp: "1.7.10" }  # TODO verify (3.27 values)
    max_known: { agp: "8.7.1", gradle: "8.10.2" }
    defaults: { compileSdk: 35, targetSdk: 35, minSdk: 21, ndk: "26.1.10909125" }
    builtin_kotlin: { supported: false, legacy_kgp_flag: false }
  "3.27":
    verified: { java: "17", kgp: "1.8.22", agp: "8.1.0", gradle: "8.3" }  # java derived from AGP 8.x
    minimums: { gradle: "7.0.2", agp: "7.0.0", kgp: "1.7.0" }
    warn_below: { java: "11", gradle: "7.1.0", agp: "7.0.1", kgp: "1.7.10" }
    max_known: { agp: "8.5", gradle: "8.7" }
    defaults: { compileSdk: 35, targetSdk: 35, minSdk: 21, ndk: "26.1.10909125" }
    builtin_kotlin: { supported: false, legacy_kgp_flag: false }
  "3.24":
    verified: { java: "11", kgp: "1.7.10", agp: "7.3.0", gradle: "7.6.3" }  # java derived from AGP 7.x
    minimums: { gradle: "7.0.2", agp: "7.0.0", kgp: "1.7.0" }
    warn_below: { java: "11", gradle: "7.1.0", agp: "7.0.1", kgp: "1.7.10" }
    max_known: { agp: "8.3", gradle: "8.0.2" }
    defaults: { compileSdk: 34, targetSdk: 34, minSdk: 21, ndk: "23.1.7779620" }
    builtin_kotlin: { supported: false, legacy_kgp_flag: false }
  "3.22":
    verified: { java: "11", kgp: "1.7.10", agp: "7.3.0", gradle: "7.6.3" }  # java derived from AGP 7.x
    max_known: { agp: "8.3", gradle: "8.0.2" }
    defaults: { compileSdk: 34, targetSdk: 34, minSdk: 21, ndk: "23.1.7779620" }
    builtin_kotlin: { supported: false, legacy_kgp_flag: false }
  "3.19":
    verified: { java: "11", kgp: "1.7.10", agp: "7.3.0", gradle: "7.6.3" }  # java derived from AGP 7.x
    max_known: { agp: "8.3", gradle: "8.0.2" }
    defaults: { compileSdk: 34, targetSdk: 33, minSdk: 19, ndk: "23.1.7779620" }
    builtin_kotlin: { supported: false, legacy_kgp_flag: false }
  "3.16":
    verified: { java: "11", kgp: "1.7.10", agp: "7.3.0", gradle: "7.5" }  # java derived from AGP 7.x
    max_known: { agp: "8.3", gradle: "8.0.2" }
    defaults: { compileSdk: 33, targetSdk: 33, minSdk: 19, ndk: "23.1.7779620" }
    builtin_kotlin: { supported: false, legacy_kgp_flag: false }

# AGP release series -> minimum Gradle and minimum JDK.
# Source: developer.android.com/build/releases/gradle-plugin (+ past-releases).
agp:
  - { series: "9.4", min_gradle: "9.6.0", min_jdk: 17 }
  - { series: "9.3", min_gradle: "9.5.0", min_jdk: 17 }
  - { series: "9.2", min_gradle: "9.4.1", min_jdk: 17 }
  - { series: "9.1", min_gradle: "9.3.1", min_jdk: 17 }
  - { series: "9.0", min_gradle: "9.1.0", min_jdk: 17 }
  - { series: "8.13", min_gradle: "8.13", min_jdk: 17 }
  - { series: "8.12", min_gradle: "8.13", min_jdk: 17 }  # derived: 8.11 and 8.13 both require 8.13
  - { series: "8.11", min_gradle: "8.13", min_jdk: 17 }
  - { series: "8.10", min_gradle: "8.11.1", min_jdk: 17 }
  - { series: "8.9", min_gradle: "8.11.1", min_jdk: 17 }
  - { series: "8.8", min_gradle: "8.10.2", min_jdk: 17 }
  - { series: "8.7", min_gradle: "8.9", min_jdk: 17 }
  - { series: "8.6", min_gradle: "8.7", min_jdk: 17 }
  - { series: "8.5", min_gradle: "8.7", min_jdk: 17 }
  - { series: "8.4", min_gradle: "8.6", min_jdk: 17 }
  - { series: "8.3", min_gradle: "8.4", min_jdk: 17 }
  - { series: "8.2", min_gradle: "8.2", min_jdk: 17 }
  - { series: "8.1", min_gradle: "8.0", min_jdk: 17 }
  - { series: "8.0", min_gradle: "8.0", min_jdk: 17 }
  - { series: "7.4", min_gradle: "7.5", min_jdk: 11 }
  - { series: "7.3", min_gradle: "7.4", min_jdk: 11 }
  - { series: "7.2", min_gradle: "7.3.3", min_jdk: 11 }
  - { series: "7.1", min_gradle: "7.2", min_jdk: 11 }
  - { series: "7.0", min_gradle: "7.0", min_jdk: 11 }
  - { series: "4.2", min_gradle: "6.7.1", min_jdk: 8 }  # TODO verify
  - { series: "4.1", min_gradle: "6.5", min_jdk: 8 }    # TODO verify
  - { series: "4.0", min_gradle: "6.1.1", min_jdk: 8 }  # TODO verify

# AGP features that matter for rules.
agp_features:
  namespace_required_from: "8.0"      # `namespace` mandatory in build files
  builtin_kotlin_from: "9.0"          # AGP has Kotlin built in; kotlin-android conflicts
  builtin_kotlin_runtime_kgp: "2.2.10" # AGP 9.0/9.1 runtime KGP dependency

# Gradle version -> the newest Java it can RUN on (docs.gradle.org compatibility).
# Look-up: take the newest row whose Gradle version is <= yours.
gradle_max_java:
  - { gradle: "9.4.0", java: 26 }
  - { gradle: "9.1.0", java: 25 }
  - { gradle: "8.14", java: 24 }
  - { gradle: "8.10", java: 23 }
  - { gradle: "8.8", java: 22 }
  - { gradle: "8.5", java: 21 }
  - { gradle: "8.3", java: 20 }
  - { gradle: "7.6", java: 19 }
  - { gradle: "7.5", java: 18 }
  - { gradle: "7.3", java: 17 }
  - { gradle: "7.0", java: 16 }
  - { gradle: "6.7", java: 15 }
  - { gradle: "6.3", java: 14 }
  - { gradle: "6.0", java: 13 }
  - { gradle: "5.4", java: 12 }
  - { gradle: "5.0", java: 11 }
  - { gradle: "4.7", java: 10 }
  - { gradle: "4.3", java: 9 }
  - { gradle: "2.0", java: 8 }

# Gradle version -> the oldest Java it can RUN on.
gradle_min_java:
  - { gradle: "9.0", java: 17 }
  - { gradle: "5.0", java: 8 }

# Class-file major version -> Java version (major = java + 44).
java_class_versions:
  52: "8"
  53: "9"
  54: "10"
  55: "11"
  56: "12"
  57: "13"
  58: "14"
  59: "15"
  60: "16"
  61: "17"
  62: "18"
  63: "19"
  64: "20"
  65: "21"
  66: "22"
  67: "23"
  68: "24"
  69: "25"
  70: "26"

# Thresholds for the plugin audit (GP004).
plugin_audit:
  compile_sdk_lag: 2   # warn when a plugin hard-codes compileSdk < (Flutter default - lag)
  java_below: 11       # warn when a plugin targets Java < 11
''';

/// Contents of `data/errors.yaml` at build time.
const String bundledErrorsYaml = r'''
# Error patterns for `android_build_doctor explain`.
#
# This is DATA, not code: add a pattern by pull request in five minutes.
#
# Fields:
#   id      Stable identifier (GE###). Googleable.
#   regex   Dart/JS-style regular expression searched over the whole log.
#           Capture groups are available in `title`, `cause` and `fix` as
#           {1}, {2}, ...
#   derive  Optional. Extra placeholders computed from capture groups, e.g.
#             java: { from: 1, map: java_class_versions }
#           makes {java} available (class-file major 65 -> "21").
#   title   One line, what happened.
#   cause   Plain-language explanation.
#   fix     Steps, one per list item.
#   docs    URL with more information.
#
# Keep regexes anchored to distinctive text so they do not fire on unrelated
# logs. Test every pattern against a real log in test/fixtures/logs/.

patterns:
  - id: GE001
    regex: 'Unsupported class file major version (\d+)'
    derive:
      java: { from: 1, map: java_class_versions }
    title: Your Java is newer than your Gradle can run on
    cause: >-
      Class file major version {1} means Gradle was started with Java {java},
      but the Gradle version in your wrapper is too old to run on it. This
      usually happens after Android Studio or Homebrew upgrades the bundled
      JDK, or after switching machines.
    fix:
      - Upgrade Gradle in android/gradle/wrapper/gradle-wrapper.properties to a version that supports Java {java} (run `android_build_doctor check` to see the exact version).
      - Or point Flutter at an older JDK with `flutter config --jdk-dir=<path>`.
      - Then run `flutter clean` and build again.
    docs: https://docs.gradle.org/current/userguide/compatibility.html

  - id: GE002
    regex: "Cannot add extension with name 'kotlin', as there is an extension already registered with that name"
    title: A Kotlin plugin is applied twice (AGP 9 has Kotlin built in)
    cause: >-
      Android Gradle Plugin 9 registers the `kotlin` extension itself. A
      module (your app or one of your Flutter plugins) still applies the old
      `kotlin-android` / `org.jetbrains.kotlin.android` plugin, so Gradle
      finds two `kotlin` extensions and stops.
    fix:
      - Run `android_build_doctor plugins` to find which plugin(s) still apply KGP.
      - Upgrade those plugins to versions that are migrated to built-in Kotlin, or report the issue to the plugin author.
      - Until every plugin is ready, keep `android.builtInKotlin=false` in android/gradle.properties (supported since Flutter 3.44).
      - If your own android/app/build.gradle(.kts) applies `kotlin-android`, remove that line and replace `kotlinOptions { }` with `kotlin { compilerOptions { } }`.
    docs: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin

  - id: GE003
    regex: 'Minimum supported Gradle version is (\d+(?:\.\d+)*)\. Current version is (\d+(?:\.\d+)*)'
    title: Your Android Gradle Plugin needs a newer Gradle
    cause: >-
      The Android Gradle Plugin you use requires Gradle {1} or newer, but the
      wrapper is pinned to Gradle {2}.
    fix:
      - Edit android/gradle/wrapper/gradle-wrapper.properties and set distributionUrl to gradle-{1}-all.zip (or newer).
      - Or run `android_build_doctor fix` to do it for you.
    docs: https://developer.android.com/build/releases/gradle-plugin#updating-gradle

  - id: GE004
    regex: 'Your project requires a newer version of the Kotlin Gradle plugin'
    title: Your Kotlin Gradle Plugin is too old for Flutter
    cause: >-
      Flutter's Android embedding depends on libraries that need a newer
      Kotlin Gradle Plugin (KGP) than the one declared in your project.
    fix:
      - Update the KGP version in android/settings.gradle(.kts) (`org.jetbrains.kotlin.android`) or, in older projects, `ext.kotlin_version` in android/build.gradle.
      - Run `android_build_doctor check` to see the version Flutter verified for your release.
    docs: https://docs.flutter.dev/release/breaking-changes/kotlin-version

  - id: GE005
    regex: 'Module was compiled with an incompatible version of Kotlin\. The binary version of its metadata is (\d+(?:\.\d+)*), expected version is (\d+(?:\.\d+)*)'
    title: A dependency was built with a newer Kotlin than yours
    cause: >-
      A library (often a plugin's AAR or a Flutter engine artifact) was
      compiled with Kotlin metadata {1}, but your Kotlin Gradle Plugin only
      understands up to {2}.
    fix:
      - Raise your Kotlin Gradle Plugin version in android/settings.gradle(.kts) so its metadata version is at least {1}.
      - If you are on AGP 9, remove the explicit KGP version and let AGP's built-in Kotlin handle it.
    docs: https://kotlinlang.org/docs/gradle-configure-project.html

  - id: GE006
    regex: 'Namespace not specified\.'
    title: A module has no `namespace` (required since AGP 8)
    cause: >-
      Android Gradle Plugin 8 and newer require every module to declare
      `namespace` in its build file instead of relying on the `package`
      attribute of AndroidManifest.xml.
    fix:
      - If the module is your app, add `namespace = "your.application.id"` inside `android { }` in android/app/build.gradle(.kts), or run `android_build_doctor fix`.
      - If the module is a plugin (see the culprit above), upgrade the plugin; newer versions add the namespace.
    docs: https://developer.android.com/build/configure-app-module#set-namespace

  - id: GE007
    regex: "Inconsistent JVM-target compatibility detected for tasks '([^']+)' \\(([\\d.]+)\\) and '([^']+)' \\(([\\d.]+)\\)"
    title: Java and Kotlin compile to different JVM targets
    cause: >-
      Task {1} targets JVM {2} while task {3} targets JVM {4}. Kotlin refuses
      to mix targets inside one module.
    fix:
      - In android/app/build.gradle(.kts) set `sourceCompatibility`, `targetCompatibility` and the Kotlin `jvmTarget` to the same value (17 is the Flutter default).
      - If the module is a plugin, upgrade the plugin.
    docs: https://kotlinlang.org/docs/gradle-configure-project.html#check-for-jvm-target-compatibility-of-related-compile-tasks

  - id: GE008
    regex: 'uses-sdk:minSdkVersion (\d+) cannot be smaller than version (\d+) declared in library \[([^\]]+)\]'
    title: A dependency needs a higher minSdk
    cause: >-
      Your app declares minSdk {1}, but the library {3} requires at least
      {2}.
    fix:
      - Raise `minSdk` in android/app/build.gradle(.kts) to {2} (or use `flutter.minSdkVersion` if Flutter's default is high enough).
      - Or pin an older version of the plugin that pulls in this library.
    docs: https://developer.android.com/studio/build#minSdk

  - id: GE009
    regex: 'Dependency ''([^'']+)'' requires libraries and applications that\s+depend on it to compile against version (\d+) or later of the\s+Android APIs'
    title: A dependency needs a higher compileSdk
    cause: >-
      The library {1} was built against Android API {2}; your app compiles
      against an older SDK.
    fix:
      - Set `compileSdk` in android/app/build.gradle(.kts) to {2} or newer (`flutter.compileSdkVersion` follows Flutter's default).
      - Make sure the matching platform is installed in the Android SDK Manager.
    docs: https://developer.android.com/studio/build#compileSdk

  - id: GE010
    regex: 'Could not resolve[\s\S]{0,4000}?https://jcenter\.bintray\.com'
    title: JCenter is gone; a repository still points at it
    cause: >-
      JCenter shut down in 2022. A Gradle file (yours or a plugin's) lists
      `jcenter()` and Gradle cannot download artifacts from it.
    fix:
      - Replace `jcenter()` with `mavenCentral()` in android/build.gradle(.kts) and android/settings.gradle(.kts) (`android_build_doctor fix` does this).
      - If a plugin still uses jcenter(), upgrade it; `android_build_doctor plugins` lists them.
    docs: https://developer.android.com/build/jcenter-migration

  - id: GE011
    regex: "Your project's (Gradle|Java|Android Gradle Plugin|Kotlin|minimum Android SDK) version \\(([^)]+)\\) is lower than Flutter's minimum supported version of ([^.\\n]+(?:\\.[0-9]+)*)"
    title: Flutter refuses to build with your {1} version
    cause: >-
      Flutter's Gradle plugin checks tool versions at build time. Your {1}
      version is {2}, but this Flutter release requires at least {3}.
    fix:
      - Upgrade {1} to {3} or newer. Run `android_build_doctor check` for the exact file and line, or `android_build_doctor fix` to apply it.
    docs: https://docs.flutter.dev/release/breaking-changes/android-java-gradle-migration-guide

  - id: GE012
    regex: "Flutter support for your project's (Gradle|Java|Android Gradle Plugin|Kotlin) version \\(([^)]+)\\) will soon be dropped"
    title: Flutter warns that your {1} version is about to lose support
    cause: >-
      Your {1} version ({2}) still builds, but a future Flutter release will
      reject it.
    fix:
      - Upgrade {1} to the version Flutter verified for your release (`android_build_doctor check` shows it).
    docs: https://docs.flutter.dev/release/breaking-changes/android-java-gradle-migration-guide

  - id: GE013
    regex: 'You are applying Flutter''s (?:main|app_plugin_loader) Gradle plugin imperatively'
    title: Deprecated imperative apply of Flutter's Gradle plugin
    cause: >-
      Your android/app/build.gradle still uses `apply from: flutter.gradle`
      (or settings.gradle uses app_plugin_loader.gradle). Flutter now expects
      the declarative `plugins { id "dev.flutter.flutter-gradle-plugin" }`.
    fix:
      - Follow the migration guide to switch to the declarative plugins block; `android_build_doctor check` reports the exact lines (GD008).
    docs: https://docs.flutter.dev/release/breaking-changes/flutter-gradle-plugin-apply

  - id: GE014
    regex: "Plugin \\[id: 'com\\.android\\.application', version: '([^']+)'(?:, apply: false)?\\] was not found"
    title: Gradle could not download Android Gradle Plugin {1}
    cause: >-
      The AGP version declared in android/settings.gradle(.kts) does not
      exist, or the Google Maven repository is unreachable.
    fix:
      - Check that AGP {1} is a real release at https://developer.android.com/build/releases/gradle-plugin and that `google()` is listed under `pluginManagement { repositories { } }`.
      - If you are offline or behind a proxy, fix network access first.
    docs: https://developer.android.com/build/releases/gradle-plugin

  - id: GE015
    regex: 'The Android Gradle plugin supports only Kotlin Gradle plugin version ([\d.]+) and higher'
    title: Your Kotlin Gradle Plugin is too old for your AGP
    cause: >-
      The Android Gradle Plugin you use needs Kotlin Gradle Plugin {1} or
      newer.
    fix:
      - Update the `org.jetbrains.kotlin.android` version in android/settings.gradle(.kts) to at least {1}.
    docs: https://developer.android.com/build/releases/gradle-plugin
''';
