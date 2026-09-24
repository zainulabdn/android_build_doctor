// Regenerates lib/src/data/bundled_data.dart from data/*.yaml.
//
// Run with: dart run tool/embed_data.dart
//
// The CLI must work when installed with `dart pub global activate`, where the
// package's data/ directory is not reliably reachable at runtime, so the YAML
// files are embedded as Dart string constants. A test asserts the embedded
// copies match the files on disk.
import 'dart:io';

void main() {
  final matrix = File('data/matrix.yaml').readAsStringSync();
  final errors = File('data/errors.yaml').readAsStringSync();
  for (final (name, text) in [('matrix', matrix), ('errors', errors)]) {
    if (text.contains("'''")) {
      stderr.writeln("data/$name.yaml must not contain ''' (triple quotes)");
      exit(1);
    }
  }
  final out = StringBuffer()
    ..writeln('// GENERATED FILE. Do not edit by hand.')
    ..writeln('// Regenerate with: dart run tool/embed_data.dart')
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln()
    ..writeln('/// Contents of `data/matrix.yaml` at build time.')
    ..writeln("const String bundledMatrixYaml = r'''")
    ..write(matrix)
    ..writeln("''';")
    ..writeln()
    ..writeln('/// Contents of `data/errors.yaml` at build time.')
    ..writeln("const String bundledErrorsYaml = r'''")
    ..write(errors)
    ..writeln("''';");
  File('lib/src/data/bundled_data.dart').writeAsStringSync(out.toString());
  stdout.writeln('wrote lib/src/data/bundled_data.dart');
}
