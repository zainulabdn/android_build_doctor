/// A `compileSdk` / `targetSdk` / `minSdk` value as written in a Gradle file.
class SdkLevel {
  /// Creates an SDK level from what was written in the build file.
  const SdkLevel({this.value, required this.expression});

  /// The numeric API level if it was a literal, `null` for expressions.
  final int? value;

  /// The exact expression, for example `34` or `flutter.compileSdkVersion`.
  final String expression;

  /// True when the value references one of Flutter's `flutter.*SdkVersion`
  /// variables, including inside an expression such as
  /// `maxOf(flutter.minSdkVersion, 23)`.
  bool get usesFlutterVariable => expression.contains('flutter.');

  /// True when the value is a literal number.
  bool get isLiteral => value != null;

  /// JSON representation used by `--json` output.
  Map<String, Object?> toJson() => {
    'value': value,
    'expression': expression,
    'uses_flutter_variable': usesFlutterVariable,
  };

  @override
  String toString() => expression;
}
