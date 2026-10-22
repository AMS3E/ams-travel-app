final _br = RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false);
final _liOpen = RegExp(r'<\s*li[^>]*>', caseSensitive: false);
final _liClose = RegExp(r'<\s*/\s*li\s*>', caseSensitive: false);
final _blockClose = RegExp(r'<\s*/\s*(p|div|h[1-6]|ul|ol|blockquote|section|article)\s*>', caseSensitive: false);
final _scriptOrStyle = RegExp(r'<\s*(script|style)[^>]*>[\s\S]*?<\s*/\s*\1\s*>', caseSensitive: false);
final _anyTag = RegExp(r'<[^>]*>');
final _hexEntity = RegExp(r'&#x([0-9a-fA-F]+);');
final _decimalEntity = RegExp(r'&#(\d+);');
final _spaces = RegExp(r'[ \t\r\f]+');
final _blankLines = RegExp(r'\n{3,}');
final _bullet = RegExp(r'^[•\-*]\s*');

/// Named entities the CMS writes. `&amp;` is decoded last so `&amp;lt;`
/// stays `&lt;`.
const _entities = {
  '&nbsp;': ' ',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&apos;': "'",
  '&rsquo;': '’',
  '&lsquo;': '‘',
  '&ldquo;': '“',
  '&rdquo;': '”',
  '&mdash;': '—',
  '&ndash;': '–',
  '&amp;': '&',
};

/// The API's descriptions may be HTML. This turns them into readable plain
/// text: paragraphs and line breaks kept, list items bulleted, entities
/// decoded, every other tag dropped.
String htmlToText(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  var t = html
      .replaceAll(_br, '\n')
      .replaceAll(_liOpen, '\n• ')
      .replaceAll(_liClose, '')
      .replaceAll(_blockClose, '\n\n')
      .replaceAll(_scriptOrStyle, '')
      .replaceAll(_anyTag, '')
      .replaceAllMapped(_hexEntity, (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
      .replaceAllMapped(_decimalEntity, (m) => String.fromCharCode(int.parse(m[1]!)));
  _entities.forEach((entity, char) => t = t.replaceAll(entity, char));
  final lines = [for (final l in t.split('\n')) l.replaceAll(_spaces, ' ').trim()];
  return lines.join('\n').replaceAll(_blankLines, '\n\n').trim();
}

/// [htmlToText] as its non-empty lines, without list bullets: one entry per
/// paragraph, line or list item.
List<String> htmlToLines(String? html) => [
  for (final l in htmlToText(html).split('\n'))
    if (l.replaceFirst(_bullet, '').trim() case final line when line.isNotEmpty) line,
];
