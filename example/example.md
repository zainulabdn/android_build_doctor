# android_build_doctor examples

## Diagnose a project

```bash
cd my_flutter_app
android_build_doctor check
```

## Find which plugins block AGP 9 / built-in Kotlin

```bash
android_build_doctor plugins
# AGP 9 + built-in Kotlin readiness: 37/40 plugins ready. Blockers: file_picker, geocoding, some_old_plugin.
```

## Explain a failed build

```bash
flutter build apk 2>&1 | android_build_doctor explain -
```

## Preview and apply fixes

```bash
android_build_doctor fix --dry-run   # diff only
android_build_doctor fix             # asks before writing, backs files up
android_build_doctor restore         # undo
```

## Plan an upgrade

```bash
android_build_doctor --target 3.47.0 check
```

## CI

```bash
android_build_doctor check --ci --json > android-doctor.json
```

## As a library

```dart
import 'package:android_build_doctor/android_build_doctor.dart';

Future<void> main() async {
  final matrix = await MatrixLoader().load(offline: true);
  final snapshot = await ProjectDetector().detect('.', scanPlugins: true);
  final ctx = RuleContext(snapshot: snapshot, matrix: matrix);
  final findings = runRules([...projectRules, ...pluginRules], ctx);
  for (final f in findings) {
    print('${f.id} [${f.severity.label}] ${f.message} (${f.source})');
  }
}
```
