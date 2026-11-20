import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/plan_collection_service.dart';
import 'package:ascent/features/plans/plan_adjust.dart';
import 'package:ascent/features/plans/plan_templates.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PlanCollectionService service;
  late String id;
  final now = DateTime.now();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = PlanCollectionService(db);
    id = await service.save(
      title: 'Study',
      items: draftsFor(
        const [
          PlanStep(
            title: 'Study session',
            time: TimeOfDay(hour: 23, minute: 59),
            minutes: 60,
          ),
        ],
        start: now,
        weeks: 2,
        now: now,
      ),
      requestId: 'adjust_test',
    );
  });
  tearDown(() => db.close());

  Future<PlanItemView> item() async =>
      (await service.watchItems(id).first).single;

  test('lighter: weekdays and a shorter session, then Undo', () async {
    final before = await item();
    expect(before.recurrence, 'daily');
    final a = lighter([before], now);
    expect(a.isEmpty, isFalse);
    final undo = await applyAdjustment(service, id, a);

    final after = await item();
    expect(after.recurrence, 'weekdays');
    expect(after.minutes, 45);

    await undo();
    final back = await item();
    expect(back.recurrence, 'daily');
    expect(back.minutes, 60);
  });

  test('already light: nothing to change', () async {
    final a = lighter([await item()], now);
    await applyAdjustment(service, id, a);
    final again = lighter([await item()], now);
    // 45 → 35 is still possible once more; after that it stays put.
    await applyAdjustment(service, id, again);
    var steps = 0;
    while (!lighter([await item()], now).isEmpty && steps < 5) {
      await applyAdjustment(service, id, lighter([await item()], now));
      steps++;
    }
    expect(lighter([await item()], now).isEmpty, isTrue);
    expect((await item()).minutes, greaterThanOrEqualTo(10));
  });

  test('extend: one more week, then Undo', () async {
    final before = await item();
    final end = before.endDate!;
    final undo = await applyAdjustment(service, id, extend([before], now));
    expect((await item()).endDate, end.add(const Duration(days: 7)));
    await undo();
    expect((await item()).endDate, end);
  });
}
