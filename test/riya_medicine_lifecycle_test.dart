import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:ascent/core/ai/riya_intents.dart';

void main() {
  late AppDatabase db;
  late RiyaExecutor executor;
  late RiyaIntentResolver resolver;
  var now = DateTime(2027, 1, 31, 10);
  setUp(() {
    now = DateTime(2027, 1, 31, 10);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    executor = RiyaExecutor(db, clock: () => now);
    resolver = RiyaIntentResolver(db, clock: () => now);
  });
  tearDown(() async => db.close());
  Future<RiyaResult> run(RiyaCommand command, String request) =>
      executor.execute(command, requestId: request, approved: true);
  test(
    'Natural schedule commands require supplied dosage and confirm/replay atomically',
    () async {
      expect(
        (await resolver.resolve('Add medicine My schedule'))!.command,
        isNull,
      );
      final command = (await resolver.resolve(
        'Add medicine My schedule dosage My dose form tablet at 08:00, 20:00 for 3 days',
      ))!.command!;
      await expectLater(
        executor.execute(command, requestId: 'no'),
        throwsStateError,
      );
      final result = await run(command, 'create');
      expect((await run(command, 'create')).replayed, true);
      expect(await db.select(db.medicineTable).get(), hasLength(1));
      expect(await db.select(db.medicineLogTable).get(), hasLength(6));
      expect(
        (await db.medicineDao.getMedicineById(result.entityId!))!.instructions,
        'As recorded',
      );
      resolver.rememberResult(result);
      final edit = (await resolver.resolve(
        'Edit that name to New schedule',
      ))!.command!;
      await run(edit, 'rename');
      expect(
        (await db.medicineDao.getMedicineById(result.entityId!))!.name,
        'New schedule',
      );
      await run(
        RiyaCommand('medicine.edit', {'id': result.entityId!, 'active': false}),
        'pause',
      );
      expect(
        (await db.select(db.reminderTable).get())
            .where((r) => r.scheduledAt.isAfter(now))
            .every((r) => !r.isActive),
        true,
      );
      await run(
        RiyaCommand('medicine.delete', {'id': result.entityId!}),
        'delete',
      );
      expect(await db.select(db.medicineTable).get(), isEmpty);
      expect(
        (await run(
          RiyaCommand('medicine.delete', {'id': result.entityId!}),
          'delete',
        )).replayed,
        true,
      );
    },
  );
  test(
    'Dose correction is scoped to a real log and preserves taken timestamp on replay',
    () async {
      final command = (await resolver.resolve(
        'Add medicine My schedule dosage My dose form tablet at 20:00 for 2 days',
      ))!.command!;
      await run(command, 'create');
      final dose = (await db.select(db.medicineLogTable).get()).first;
      final taken = (await resolver.resolve(
        'Mark dose #${dose.id} taken',
      ))!.command!;
      await run(taken, 'taken');
      final timestamp =
          (await db.select(db.medicineLogTable).get()).first.takenAt;
      await run(taken, 'taken');
      expect(
        (await db.select(db.medicineLogTable).get()).first.takenAt,
        timestamp,
      );
      expect(
        (await db.taskDao.getTaskById(dose.linkedTaskId!))!.actualCompletedDate,
        isNotNull,
      );
      await run(
        RiyaCommand('medicine.taken', {'id': dose.id, 'taken': false}),
        'correct',
      );
      expect(
        (await db.taskDao.getTaskById(dose.linkedTaskId!))!.actualCompletedDate,
        isNull,
      );
      expect(
        (await db.reminderDao.getReminderById(
          dose.linkedReminderId!,
        ))!.alertSyncPending,
        true,
      );
      await expectLater(
        run(
          const RiyaCommand('medicine.taken', {'id': 99999, 'taken': true}),
          'missing',
        ),
        throwsStateError,
      );
    },
  );
  test(
    'Dose pages keep date across midnight and relinquish scope for reminders',
    () async {
      await run(
        const RiyaCommand('medicine.create', {
          'name': 'My schedule',
          'dosage': 'My dose',
          'form': 'tablet',
          'times': ['11:00', '12:00', '13:00', '14:00'],
          'days': 2,
        }),
        'create',
      );
      final command = (await resolver.resolve('Doses today'))!.command!;
      expect(
        RegExp(r'Dose #').allMatches((await run(command, 'list')).message),
        hasLength(3),
      );
      now = DateTime(2027, 2, 1);
      final more = (await resolver.resolve('More doses'))!.command!;
      expect(DateTime.parse(more.arguments['day']), DateTime(2027, 1, 31));
      expect(
        RegExp(r'Dose #').allMatches((await run(more, 'more')).message),
        hasLength(1),
      );
      await resolver.resolve('Show reminders');
      expect(
        (await resolver.resolve('Tomorrow'))!.command!.id,
        'reminders.list',
      );
    },
  );
  test(
    'Invalid or failed scheduling leaves no schedule, projections or receipt',
    () async {
      final arguments = {
        'name': 'User schedule',
        'dosage': 'My dose',
        'form': 'tablet',
        'times': ['25:00'],
        'days': 2,
      };
      await expectLater(
        run(RiyaCommand('medicine.create', arguments), 'bad'),
        throwsArgumentError,
      );
      await db.customStatement(
        "CREATE TRIGGER fail_dose BEFORE INSERT ON medicine_logs BEGIN SELECT RAISE(ABORT,'disk failure'); END;",
      );
      await expectLater(
        run(
          RiyaCommand('medicine.create', {
            ...arguments,
            'times': ['08:00'],
          }),
          'disk',
        ),
        throwsA(anything),
      );
      expect(await db.select(db.medicineTable).get(), isEmpty);
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.reminderTable).get(), isEmpty);
      expect(await db.select(db.aiCommandTable).get(), isEmpty);
    },
  );
}
