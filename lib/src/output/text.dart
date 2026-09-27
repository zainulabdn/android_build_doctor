/// Width-aware text helpers for terminal layout. They ignore ANSI escape
/// codes, so styled text can be measured, padded and shortened.
library;

final RegExp _escape = RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]');

/// `text` without ANSI escape sequences.
String stripAnsi(String text) => text.replaceAll(_escape, '');

/// Number of terminal cells `text` occupies. Escape codes take none, East
/// Asian wide characters and emoji take two, combining marks take none.
int visibleWidth(String text) {
  var width = 0;
  for (final rune in stripAnsi(text).runes) {
    width += _runeWidth(rune);
  }
  return width;
}

int _runeWidth(int r) {
  if (r < 0x20 || (r >= 0x7F && r < 0xA0)) return 0;
  if ((r >= 0x0300 && r <= 0x036F) ||
      (r >= 0x200B && r <= 0x200F) ||
      (r >= 0xFE00 && r <= 0xFE0F)) {
    return 0;
  }
  if ((r >= 0x1100 && r <= 0x115F) ||
      (r >= 0x2E80 && r <= 0xA4CF && r != 0x303F) ||
      (r >= 0xAC00 && r <= 0xD7A3) ||
      (r >= 0xF900 && r <= 0xFAFF) ||
      (r >= 0xFE30 && r <= 0xFE4F) ||
      (r >= 0xFF00 && r <= 0xFF60) ||
      (r >= 0xFFE0 && r <= 0xFFE6) ||
      (r >= 0x1F300 && r <= 0x1FAFF) ||
      (r >= 0x20000 && r <= 0x3FFFD)) {
    return 2;
  }
  return 1;
}

/// `text` padded with spaces to `width` cells (never shortened).
String padVisible(String text, int width) {
  final gap = width - visibleWidth(text);
  return gap > 0 ? '$text${' ' * gap}' : text;
}

/// `text` shortened to at most `width` cells, ending in `ellipsis` when
/// something was cut. Escape codes are kept, and a reset is appended after
/// a cut so a style never leaks past the shortened text.
String truncateVisible(String text, int width, {String ellipsis = '…'}) {
  if (visibleWidth(text) <= width) return text;
  final room = width - visibleWidth(ellipsis);
  if (room <= 0) return ellipsis.substring(0, width.clamp(0, ellipsis.length));
  final out = StringBuffer();
  var used = 0;
  var styled = false;
  var i = 0;
  while (i < text.length) {
    final m = _escape.matchAsPrefix(text, i);
    if (m != null) {
      out.write(m.group(0));
      styled = true;
      i = m.end;
      continue;
    }
    var rune = text.codeUnitAt(i);
    var units = 1;
    if (rune >= 0xD800 && rune <= 0xDBFF && i + 1 < text.length) {
      final low = text.codeUnitAt(i + 1);
      if (low >= 0xDC00 && low <= 0xDFFF) {
        rune = 0x10000 + ((rune - 0xD800) << 10) + (low - 0xDC00);
        units = 2;
      }
    }
    final w = _runeWidth(rune);
    if (used + w > room) break;
    out.write(text.substring(i, i + units));
    used += w;
    i += units;
  }
  out.write(ellipsis);
  if (styled) out.write('\x1B[0m');
  return out.toString();
}

/// Word-wraps plain `text` to lines of at most `width` cells. Newlines start
/// new paragraphs. A word longer than `width` is split when `breakWords` is
/// true and left whole (to overflow) otherwise, which keeps URLs and paths
/// copyable.
List<String> wrapWords(String text, int width, {bool breakWords = true}) {
  if (width < 1) return [text];
  final lines = <String>[];
  for (final paragraph in text.split('\n')) {
    var line = '';
    for (final word in paragraph.split(' ')) {
      if (word.isEmpty) continue;
      final candidate = line.isEmpty ? word : '$line $word';
      if (visibleWidth(candidate) <= width) {
        line = candidate;
        continue;
      }
      if (line.isNotEmpty) lines.add(line);
      var rest = word;
      while (breakWords && visibleWidth(rest) > width) {
        lines.add(rest.substring(0, width));
        rest = rest.substring(width);
      }
      line = rest;
    }
    lines.add(line);
  }
  return lines;
}
