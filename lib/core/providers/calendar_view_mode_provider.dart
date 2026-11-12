import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ephemeral presentation only; no preference or personal record is written.
/// The shell uses this to match its navigation to Calendar versus reminder list.
final calendarViewModeProvider = NotifierProvider<CalendarViewMode, bool>(
  CalendarViewMode.new,
);

class CalendarViewMode extends Notifier<bool> {
  @override
  bool build() => false;
  void showCalendar(bool value) {
    if (state != value) state = value;
  }
}
