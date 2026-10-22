/// Compares visible action text without treating wrapping or casing as content.
bool sameActionText(String left, String right) {
  String comparable(String text) =>
      text.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  return comparable(left) == comparable(right);
}

/// Returns supporting notes without repeating the action title.
/// This is display-safe for legacy records and never rewrites stored content.
String? actionSupportingText(String title, String? content) {
  final body = content?.trim() ?? '';
  if (body.isEmpty) return null;
  final heading = title.trim();
  if (sameActionText(heading, body)) return null;
  if (heading.isNotEmpty &&
      body.toLowerCase().startsWith(heading.toLowerCase()) &&
      body.length > heading.length &&
      RegExp(r'\s').hasMatch(body[heading.length])) {
    final remainder = body.substring(heading.length).trim();
    return remainder.isEmpty ? null : remainder;
  }
  return body;
}
