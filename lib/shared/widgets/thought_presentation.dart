/// Adds display-only quotation marks; stored text and shared content stay intact.
String quotedThought(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return content;
  const pairs = [('“', '”'), ('"', '"'), ('‘', '’'), ("'", "'"), ('«', '»')];
  for (final pair in pairs) {
    if (trimmed.startsWith(pair.$1) &&
        trimmed.endsWith(pair.$2) &&
        trimmed.length >= 2) {
      return content;
    }
  }
  return '“$content”';
}
