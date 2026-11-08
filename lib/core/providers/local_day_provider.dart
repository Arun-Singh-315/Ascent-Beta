import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared wall clock, driven by the app's lifecycle boundary.
final localClockProvider = NotifierProvider<LocalClock, DateTime>(
  LocalClock.new,
);

class LocalClock extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();
  void refresh() => state = DateTime.now();
}

final localDayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(localClockProvider);
  return DateTime(now.year, now.month, now.day);
});
final localHourProvider = Provider<int>(
  (ref) => ref.watch(localClockProvider).hour,
);
