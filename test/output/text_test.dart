import 'package:android_build_doctor/android_build_doctor.dart';
import 'package:test/test.dart';

void main() {
  final a = Ansi(depth: ColorDepth.trueColor);

  test('visibleWidth ignores escapes and counts wide characters twice', () {
    expect(visibleWidth(a.fg(Tones.error, 'abc')), 3);
    expect(visibleWidth('╭─ ✓ ▲ ✗ ●'), 10);
    expect(visibleWidth('日本'), 4);
    expect(visibleWidth('é'), 1);
  });

  test('padVisible pads styled text by what is visible', () {
    final padded = padVisible(a.bold('ab'), 5);
    expect(stripAnsi(padded), 'ab   ');
    expect(padVisible('abcdef', 3), 'abcdef');
  });

  test('truncateVisible keeps escapes and resets after a cut', () {
    expect(truncateVisible('abcdef', 6), 'abcdef');
    expect(truncateVisible('abcdef', 4), 'abc…');
    expect(truncateVisible('abcdef', 5, ellipsis: '...'), 'ab...');
    final cut = truncateVisible(a.fg(Tones.good, 'abcdef'), 4);
    expect(stripAnsi(cut), 'abc…');
    expect(cut, endsWith('\x1B[0m'));
    expect(visibleWidth(cut), 4);
  });

  test('wrapWords wraps on spaces and keeps long words when asked', () {
    expect(wrapWords('one two three four', 9), ['one two', 'three', 'four']);
    expect(wrapWords('a\nb c', 10), ['a', 'b c']);
    expect(
      wrapWords(
        'see https://example.com/very/long/path',
        12,
        breakWords: false,
      ),
      ['see', 'https://example.com/very/long/path'],
    );
    expect(wrapWords('abcdefghij', 4), ['abcd', 'efgh', 'ij']);
  });
}
