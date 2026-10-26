/// Normalize command framing only. User titles, doses and other values retain
/// their spelling and case; record content is never fed through this helper.
String riyaConversationPrompt(String prompt) {
  var text = prompt.trim();
  for (var i = 0; i < 3; i++) {
    text = text.replaceFirst(
      RegExp(
        r'^(?:hey riya[, ]+|riya[, ]+|please |can you |could you |would you |kya tum )',
        caseSensitive: false,
      ),
      '',
    );
  }
  text = text.replaceFirst(
    RegExp(r'^show me (?:my )?', caseSensitive: false),
    'show ',
  );
  text = text.replaceFirst(
    RegExp(r'^(?:show|list) my ', caseSensitive: false),
    'show ',
  );
  final list = RegExp(
    r'^(?:(?:meri|mere) )?(medicines|medicine|dawaiyan|courses|course) (?:dikhao|batao)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (list != null) {
    return {'courses', 'course'}.contains(list.group(1)!.toLowerCase())
        ? 'show courses'
        : 'show medicines';
  }
  final doses = RegExp(
    r'^(aaj|kal) (?:ki |ke )?doses (?:dikhao|batao)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (doses != null) {
    return 'doses ${doses.group(1)!.toLowerCase() == 'aaj' ? 'today' : 'tomorrow'}';
  }
  final modules = RegExp(
    r'^course (.+) ke modules (?:dikhao|batao)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (modules != null) return 'show modules in course ${modules.group(1)}';
  final course = RegExp(
    r'^course (.+) (?:banao|add karo)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (course != null) return 'create course ${course.group(1)}';
  final medicine = RegExp(
    r'^(?:medicine|dawai) (.+?) (dikhao|pause karo|resume karo|delete karo)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (medicine != null) {
    final verb = medicine.group(2)!.toLowerCase().split(' ').first;
    return '${verb == 'dikhao' ? 'show' : verb} medicine ${medicine.group(1)}';
  }
  if (RegExp(
    r'^(?:isko|ise) edit karo$',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'edit that';
  }
  if (RegExp(
    r'^(?:cancel karo|rehne do)$',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'cancel';
  }
  final productivityList = RegExp(
    r'^(?:(?:mere|meri)\s+)?(todos?|tasks?|promises?)\s+(?:dikhao|batao)$',
    caseSensitive: false,
  ).firstMatch(text);
  if (productivityList != null) return 'Show ${productivityList[1]}';
  if (RegExp(
    r'^(?:isko|ise) delete (?:karo|kar do)$',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'delete that';
  }
  if (RegExp(
    r'^(?:isko|ise) (?:done|complete) (?:karo|kar do)$',
    caseSensitive: false,
  ).hasMatch(text)) {
    return 'complete that';
  }
  return text;
}
