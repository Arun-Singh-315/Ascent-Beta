import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/today/models/things_sections.dart';
import 'package:flutter_test/flutter_test.dart';

TodayActivityItem _a(int id, {int? h, String src = 'task'}) {
  final n = DateTime.now();
  return TodayActivityItem(
    id: 'task_$id',
    title: 'T$id',
    sourceType: src,
    status: TodayActivityStatus.notStarted,
    elapsedSecondsToday: 0,
    categoryTag: 'Task',
    linkedTaskId: id,
    plannedDate: n,
    scheduledTime: h == null ? null : DateTime(n.year, n.month, n.day, h),
  );
}

void main() {
  test('things group by part of day, medicine together, in order', () {
    final groups = groupByDayPart([
      _a(1, h: 18),
      _a(2, h: 8, src: 'medicine'),
      _a(3, h: 9),
      _a(4),
      _a(5, h: 13),
      _a(6, h: 20, src: 'medicine'),
    ]);
    expect(groups.map((g) => g.$1), [
      DayPart.morning,
      DayPart.afternoon,
      DayPart.evening,
      DayPart.anytime,
      DayPart.medicine,
    ]);
    expect(groups.last.$2.map((a) => a.id), ['task_2', 'task_6']);
  });

  test('empty parts are left out', () {
    expect(groupByDayPart([_a(1, h: 9)]).map((g) => g.$1), [DayPart.morning]);
    expect(groupByDayPart(const []), isEmpty);
  });

  test('dose task titles read cleanly', () {
    const raw = 'Dolo 650 (medicine) (650 mg tablet · 1) — 8:00 AM';
    expect(MedicineService.displayName(raw), 'Dolo 650');
    expect(MedicineService.displayDosage(raw), '650 mg tablet · 1');
    expect(MedicineService.displayName('Call mom'), 'Call mom');
    expect(MedicineService.displayDosage('Call mom'), isNull);
  });
}
