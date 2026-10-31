/// Path of a space page ("Movies", "Books" …). The space is passed as `key`.
const thoughtSpacePath = '/thought-wall/space';

/// Location for a space page, optionally highlighting one entry.
String thoughtSpaceLocation(String key, {int? highlight}) => Uri(
  path: thoughtSpacePath,
  queryParameters: {'key': key, if (highlight != null) 'thought': '$highlight'},
).toString();
