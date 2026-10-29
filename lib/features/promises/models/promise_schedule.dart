import 'dart:convert';

enum PromiseRepeat { once, daily, selectedDays, weekly }

enum PromiseDayState { done, partial, missed, pending, upcoming, off, paused }

DateTime promiseDay(DateTime date) => DateTime(date.year, date.month, date.day);
String promiseDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime promiseWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);
const _unchanged = Object();

class PromiseSchedule {
  const PromiseSchedule({
    required this.startDate,
    this.repeat = PromiseRepeat.once,
    this.endDate,
    this.plannedTime,
    this.days = const [1, 2, 3, 4, 5, 6, 7],
  });
  final DateTime startDate;
  final DateTime? endDate;
  final PromiseRepeat repeat;
  final String? plannedTime;
  final List<int> days;
  bool get repeats => repeat != PromiseRepeat.once;

  bool includes(DateTime date) {
    final day = promiseDay(date);
    if (day.isBefore(promiseDay(startDate)) ||
        (endDate != null && day.isAfter(promiseDay(endDate!)))) {
      return false;
    }
    return switch (repeat) {
      PromiseRepeat.once => day == promiseDay(endDate ?? startDate),
      PromiseRepeat.daily || PromiseRepeat.weekly => true,
      PromiseRepeat.selectedDays => days.contains(day.weekday),
    };
  }

  String get summary => switch (repeat) {
    PromiseRepeat.once => 'Once',
    PromiseRepeat.daily => 'Every day',
    PromiseRepeat.weekly => 'Weekly goal',
    PromiseRepeat.selectedDays =>
      days
          .map(
            (d) =>
                const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d - 1],
          )
          .join(', '),
  };

  void validate() {
    if (endDate != null &&
        promiseDay(endDate!).isBefore(promiseDay(startDate))) {
      throw ArgumentError('Choose an end date on or after the start.');
    }
    if (repeat == PromiseRepeat.selectedDays &&
        (days.isEmpty || days.any((d) => d < 1 || d > 7))) {
      throw ArgumentError('Choose at least one day.');
    }
    if (plannedTime != null && !validPromiseTime(plannedTime!)) {
      throw ArgumentError('Choose a valid time.');
    }
  }

  PromiseSchedule copyWith({
    DateTime? startDate,
    PromiseRepeat? repeat,
    Object? endDate = _unchanged,
    Object? plannedTime = _unchanged,
    List<int>? days,
  }) => PromiseSchedule(
    startDate: startDate ?? this.startDate,
    repeat: repeat ?? this.repeat,
    endDate: identical(endDate, _unchanged)
        ? this.endDate
        : endDate as DateTime?,
    plannedTime: identical(plannedTime, _unchanged)
        ? this.plannedTime
        : plannedTime as String?,
    days: days ?? this.days,
  );

  Map<String, dynamic> toJson() => {
    'start': promiseDateKey(startDate),
    'end': endDate == null ? null : promiseDateKey(endDate!),
    'repeat': repeat.name,
    'time': plannedTime,
    'days': days,
  };
  String encode() => jsonEncode(toJson());
  factory PromiseSchedule.fromJson(Map<String, dynamic> json) =>
      PromiseSchedule(
        startDate: DateTime.parse(json['start'] as String),
        endDate: json['end'] == null
            ? null
            : DateTime.parse(json['end'] as String),
        repeat: PromiseRepeat.values.byName(json['repeat'] as String),
        plannedTime: json['time'] as String?,
        days: (json['days'] as List).cast<int>(),
      );
  static PromiseSchedule? decode(String? raw) {
    if (raw == null) return null;
    try {
      final schedule = PromiseSchedule.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      schedule.validate();
      return schedule;
    } catch (_) {
      return null;
    }
  }
}

bool validPromiseTime(String value) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value);
  return match != null &&
      int.parse(match[1]!) < 24 &&
      int.parse(match[2]!) < 60;
}

class PromiseDayRecord {
  const PromiseDayRecord({
    required this.date,
    required this.state,
    this.amount = 0,
    this.target = 1,
    this.note,
  });
  final DateTime date;
  final PromiseDayState state;
  final double amount, target;
  final String? note;
  String get label => switch (state) {
    PromiseDayState.done => 'Done',
    PromiseDayState.partial => 'Partial',
    PromiseDayState.missed => 'Missed',
    PromiseDayState.pending => 'Pending',
    PromiseDayState.upcoming => 'Upcoming',
    PromiseDayState.off => 'Not scheduled',
    PromiseDayState.paused => 'Paused',
  };
}
