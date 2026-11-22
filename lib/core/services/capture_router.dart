import 'quick_capture_service.dart' show CaptureKind;

/// What the router thinks one unprefixed capture line is.
///
/// [text] is the line with the routing words removed ("spent 250 on lunch"
/// becomes "250 on lunch"; the amount is pulled out later). [alternative] is
/// set when the guess is unsure, so the sheet can offer a one-tap switch.
class CaptureGuess {
  const CaptureGuess(
    this.kind,
    this.text, {
    this.alternative,
    this.amount,
    this.minutes,
  });
  final CaptureKind kind;
  final String text;
  final CaptureKind? alternative;

  /// Pre-computed amount (water glasses and litres), else parsed later.
  final double? amount;

  /// Focus length for timed activities ("45m", "1h", "30 min").
  final int? minutes;
}

final _money = RegExp(r'(?:₹|\brs\.?)\s*\d', caseSensitive: false);
final _number = RegExp(r'\d');
final _expenseVerb = RegExp(
  r'^(?:i\s+)?(?:spent|paid|bought|spend|pay)\b\s*',
  caseSensitive: false,
);
final _incomeWord = RegExp(
  r'^(?:i\s+)?(?:got paid|received|earned|salary|refund|income)\b\s*',
  caseSensitive: false,
);
final _ml = RegExp(r'\b(\d{1,4})\s*ml\b', caseSensitive: false);
final _litre = RegExp(
  r'\b(\d(?:\.\d)?)\s*(?:l|ltr|litres?|liters?)\b',
  caseSensitive: false,
);
final _glasses = RegExp(
  r'\b(a|an|one|two|three|four|\d)?\s*(glass(?:es)?|bottles?|cups?)\s+of\s+water\b',
  caseSensitive: false,
);
final _drankWater = RegExp(
  r'^(?:i\s+)?(?:drank|drink|had)\s+(?:some\s+)?water$',
  caseSensitive: false,
);
final _thoughtStart = RegExp(
  r'^(?:i feel|i think|i wonder|i wish|what if|maybe|why|how come|note to self|remember that|grateful|thankful)\b',
  caseSensitive: false,
);
final _duration = RegExp(
  r'\b(?:for\s+)?(\d{1,3})\s*(m|min|mins|minutes?|h|hr|hrs|hours?)\b',
  caseSensitive: false,
);
final _clockOrDay = RegExp(
  r'\bat\s+\d|\b\d{1,2}(?::\d{2})?\s*(?:am|pm)\b|\btoday\b|\btomorrow\b|\btonight\b',
  caseSensitive: false,
);

const _counts = {'a': 1, 'an': 1, 'one': 1, 'two': 2, 'three': 3, 'four': 4};

/// Decides what an unprefixed line is. Pure and offline: the same text always
/// gives the same answer, and nothing is executed.
///
/// Order matters: money and water are the most specific signals, then focus
/// durations, then thought-like phrasing. Everything else stays a to-do, which
/// the caller may turn into a reminder or routine from its time words.
CaptureGuess guessCaptureKind(String raw) {
  final text = raw.trim();
  final lower = text.toLowerCase();

  // ── Money ────────────────────────────────────────────────────────────────
  final income = _incomeWord.firstMatch(text);
  if (income != null && _number.hasMatch(text)) {
    return CaptureGuess(CaptureKind.income, text.substring(income.end).trim());
  }
  final expense = _expenseVerb.firstMatch(text);
  if (expense != null && _number.hasMatch(text)) {
    return CaptureGuess(
      CaptureKind.expense,
      text.substring(expense.end).trim(),
    );
  }
  if (_money.hasMatch(text)) {
    return CaptureGuess(CaptureKind.expense, text);
  }

  // ── Water ────────────────────────────────────────────────────────────────
  if (lower.contains('water') || _ml.hasMatch(text)) {
    final ml = _ml.firstMatch(text);
    if (ml != null) {
      return CaptureGuess(
        CaptureKind.water,
        'Water',
        amount: double.parse(ml[1]!),
      );
    }
    final litre = _litre.firstMatch(text);
    if (litre != null && lower.contains('water')) {
      return CaptureGuess(
        CaptureKind.water,
        'Water',
        amount: (double.parse(litre[1]!) * 1000).roundToDouble(),
      );
    }
    final glass = _glasses.firstMatch(text);
    if (glass != null) {
      final word = (glass[1] ?? 'a').toLowerCase();
      final count = _counts[word] ?? int.tryParse(word) ?? 1;
      final each = glass[2]!.toLowerCase().startsWith('bottle') ? 500 : 250;
      return CaptureGuess(
        CaptureKind.water,
        'Water',
        amount: (count * each).toDouble(),
      );
    }
    if (_drankWater.hasMatch(text)) {
      return const CaptureGuess(CaptureKind.water, 'Water', amount: 250);
    }
  }

  // ── Focus (timed activity) ─────────────────────────────────────────────────
  final duration = _duration.firstMatch(text);
  if (duration != null && !lower.contains('every')) {
    final value = int.parse(duration[1]!);
    final unit = duration[2]!.toLowerCase();
    final minutes = unit.startsWith('h') ? value * 60 : value;
    if (minutes >= 1 && minutes <= 1440) {
      final title = text
          .replaceRange(duration.start, duration.end, '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (title.isNotEmpty) {
        return CaptureGuess(
          CaptureKind.timer,
          title,
          minutes: minutes,
          alternative: CaptureKind.todo,
        );
      }
    }
  }

  // ── Thought ────────────────────────────────────────────────────────────────
  if (!_clockOrDay.hasMatch(text)) {
    if (_thoughtStart.hasMatch(text) || text.endsWith('?')) {
      return CaptureGuess(
        CaptureKind.thought,
        text,
        alternative: CaptureKind.todo,
      );
    }
    final words = text.split(RegExp(r'\s+')).length;
    if (words >= 12) {
      return CaptureGuess(
        CaptureKind.thought,
        text,
        alternative: CaptureKind.todo,
      );
    }
  }

  return CaptureGuess(CaptureKind.todo, text);
}
