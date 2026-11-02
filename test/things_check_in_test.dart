import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/things_check_in.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 2, 9);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> task(
    String title, {
    DateTime? planned,
    DateTime? done,
    int? thought,
    String priority = 'medium',
  }) => db.taskDao.insertTask(
    TaskTableCompanion.insert(
      title: title,
      plannedDate: drift.Value(planned),
      actualCompletedDate: drift.Value(done),
      linkedThoughtId: drift.Value(thought),
      priority: drift.Value(priority),
    ),
  );
  Future<List<ThingsCheckIn>> plan({
    bool redact = false,
    Set<int> private = const {},
  }) async => ThingsCheckIn.plan(
    now: now,
    tasks: await db.select(db.taskTable).get(),
    reminders: await db.select(db.reminderTable).get(),
    redact: redact,
    privateThoughtIds: private,
  );

  test(
    'bundles unscheduled work, prioritizes important tasks, caps at two daytime slots',
    () async {
      await task('Clean desk');
      await task('Send proposal', priority: 'high');
      final items = await plan();
      expect(items.length, 4);
      expect(items.map((e) => e.at.hour).toList(), [11, 18, 11, 18]);
      expect(items.first.message.body, contains('Send proposal'));
      expect(items.first.message.body, contains('+1 more'));
    },
  );
  test(
    'completed, future and private work never leaks; empty hub stays quiet',
    () async {
      await task('Done', done: now);
      await task('Next month', planned: DateTime(2026, 12));
      final thoughtId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Private',
          mood: const drift.Value('promise'),
        ),
      );
      await task('Private task', thought: thoughtId);
      expect(await plan(private: {thoughtId}), isEmpty);
    },
  );
  test('redaction hides titles and completion cancels eligibility', () async {
    final id = await task('Sensitive title');
    expect(
      (await plan(redact: true)).first.message.body,
      isNot(contains('Sensitive')),
    );
    await (db.update(db.taskTable)..where((t) => t.id.equals(id))).write(
      TaskTableCompanion(actualCompletedDate: drift.Value(now)),
    );
    expect(await plan(), isEmpty);
  });
  test(
    'nearby enabled alerts suppress the slot while silent reminders do not',
    () async {
      await task('Read');
      await db
          .into(db.reminderTable)
          .insert(
            ReminderTableCompanion.insert(
              title: 'Alert',
              scheduledAt: DateTime(2026, 11, 2, 11),
              alarmEnabled: const drift.Value(true),
            ),
          );
      final items = await plan();
      expect(items.first.at, DateTime(2026, 11, 2, 18, 30));
      await db.delete(db.reminderTable).go();
      await db
          .into(db.reminderTable)
          .insert(
            ReminderTableCompanion.insert(
              title: 'Silent',
              scheduledAt: DateTime(2026, 11, 2, 11),
            ),
          );
      expect((await plan()).length, 4);
    },
  );
  test('explicit reminder takes precedence for its task', () async {
    final id = await task('Call');
    await db
        .into(db.reminderTable)
        .insert(
          ReminderTableCompanion.insert(
            title: 'Call',
            linkedTaskId: drift.Value(id),
            scheduledAt: DateTime(2026, 11, 2, 16),
            alarmEnabled: const drift.Value(true),
          ),
        );
    final items = await plan();
    expect(items.every((e) => e.at.day == 3), isTrue);
  });

  test('carries task id, deep-link payload and actionable buttons for midday and evening', () async {
    final id = await task('Finish quarterly taxes', priority: 'high');
    final items = await plan();
    expect(items.isNotEmpty, isTrue);

    final midday = items.firstWhere((e) => e.type == ThingsNotificationType.middayCheckIn);
    expect(midday.taskId, id);
    expect(midday.payload, '/things?focus=$id');
    expect(midday.actions, containsAll(['things_start', 'things_done', 'things_snooze']));

    final evening = items.firstWhere((e) => e.type == ThingsNotificationType.eveningWrapUp);
    expect(evening.taskId, id);
    expect(evening.payload, contains('/things?focus=$id&mode=wrapup'));
    expect(evening.actions, containsAll(['things_carry', 'things_review']));
  });

  test('supports 7-day horizon when requested', () async {
    await task('Weekly review', priority: 'medium');
    final items = ThingsCheckIn.plan(
      now: now,
      tasks: await db.select(db.taskTable).get(),
      reminders: await db.select(db.reminderTable).get(),
      horizonDays: 7,
    );
    // 7 days * 2 slots = 14 slots
    expect(items.length, 14);
  });
}
