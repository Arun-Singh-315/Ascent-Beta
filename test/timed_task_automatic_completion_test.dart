import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/medicine/medicine_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late int category;
  final start = DateTime(2027, 1, 1, 10);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    category = await db.timeSessionDao.insertCategory(
      SessionCategoryTableCompanion.insert(name: 'Study', colorHex: '#5FA070'),
    );
  });
  tearDown(() => db.close());
  Future<(int, int)> session({int minutes = 1, DateTime? at}) async {
    final task = await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Timed activity',
        estimatedMinutes: drift.Value(minutes),
      ),
    );
    final id = await db.timeSessionDao.startSession(
      label: 'Timed activity',
      categoryId: category,
      linkedTaskId: task,
      startedAt: at ?? start,
    );
    return (task, id);
  }

  test(
    'Manual focus completion preserves early paused and running sessions',
    () async {
      final (task, id) = await session();
      expect(
        await db.timeSessionDao.completeFocusSession(
          id,
          now: start.add(const Duration(seconds: 20)),
        ),
        false,
      );
      expect(
        (await db.timeSessionDao.getActiveFocusSession())!.status,
        'running',
      );
      await (db.update(
        db.timeSessionTable,
      )..where((s) => s.id.equals(id))).write(
        TimeSessionTableCompanion(
          status: const drift.Value('paused'),
          pausedIntervals: drift.Value(
            jsonEncode([
              {
                'pausedAt': start
                    .add(const Duration(seconds: 20))
                    .toIso8601String(),
                'resumedAt': null,
              },
            ]),
          ),
        ),
      );
      expect(
        await db.timeSessionDao.completeFocusSession(
          id,
          now: start.add(const Duration(minutes: 10)),
        ),
        false,
      );
      expect(
        (await db.timeSessionDao.getActiveFocusSession())!.status,
        'paused',
      );
      expect((await db.taskDao.getTaskById(task))!.actualCompletedDate, isNull);
    },
  );

  test(
    'Target boundary ends session and task atomically; manual Done and early completion fail',
    () async {
      final (task, id) = await session();
      expect(await db.taskDao.markComplete(task), false);
      expect(
        await db.timeSessionDao.completeTimedSessionIfTargetReached(
          id,
          now: start.add(const Duration(seconds: 59)),
        ),
        false,
      );
      expect(
        await db.timeSessionDao.completeTimedSessionIfTargetReached(
          id,
          now: start.add(const Duration(seconds: 60)),
        ),
        true,
      );
      expect(
        (await db.taskDao.getTaskById(task))!.actualCompletedDate,
        isNotNull,
      );
      final row = await (db.select(
        db.timeSessionTable,
      )..where((s) => s.id.equals(id))).getSingle();
      expect(row.status, 'completed');
      expect(row.durationSeconds, 60);
      expect(
        await db.timeSessionDao.completeTimedSessionIfTargetReached(
          id,
          now: start.add(const Duration(seconds: 90)),
        ),
        false,
      );
    },
  );
  test(
    'Pause time is excluded and previous completed work counts toward the target',
    () async {
      final (task, id) = await session(minutes: 2);
      await db
          .into(db.timeSessionTable)
          .insert(
            TimeSessionTableCompanion.insert(
              label: 'Earlier session',
              categoryId: category,
              startedAt: start.subtract(const Duration(minutes: 1)),
              linkedTaskId: drift.Value(task),
              status: const drift.Value('completed'),
              durationSeconds: const drift.Value(60),
            ),
          );
      final pauses = jsonEncode([
        {
          'pausedAt': start.add(const Duration(seconds: 10)).toIso8601String(),
          'resumedAt': start.add(const Duration(seconds: 40)).toIso8601String(),
        },
      ]);
      await (db.update(
        db.timeSessionTable,
      )..where((s) => s.id.equals(id))).write(
        TimeSessionTableCompanion(pausedIntervals: drift.Value(pauses)),
      );
      expect(
        await db.timeSessionDao.completeTimedSessionIfTargetReached(
          id,
          now: start.add(const Duration(seconds: 89)),
        ),
        false,
      );
      expect(
        await db.timeSessionDao.completeTimedSessionIfTargetReached(
          id,
          now: start.add(const Duration(seconds: 90)),
        ),
        true,
      );
      expect(
        (await db.taskDao.getTaskById(task))!.actualCompletedDate,
        isNotNull,
      );
    },
  );
  test(
    'Paused sessions and edited larger targets do not auto-complete; failed writes roll back',
    () async {
      final (task, id) = await session();
      await db.taskDao.updateTask(
        TaskTableCompanion(
          id: drift.Value(task),
          estimatedMinutes: const drift.Value(2),
        ),
      );
      expect(
        await db.timeSessionDao.completeTimedSessionIfTargetReached(
          id,
          now: start.add(const Duration(seconds: 60)),
        ),
        false,
      );
      await (db.update(
        db.timeSessionTable,
      )..where((s) => s.id.equals(id))).write(
        const TimeSessionTableCompanion(status: drift.Value('paused')),
      );
      expect(
        await db.timeSessionDao.completeTimedSessionIfTargetReached(
          id,
          now: start.add(const Duration(minutes: 10)),
        ),
        false,
      );
      await (db.update(
        db.timeSessionTable,
      )..where((s) => s.id.equals(id))).write(
        const TimeSessionTableCompanion(status: drift.Value('running')),
      );
      await db.customStatement(
        "CREATE TRIGGER fail_completion BEFORE UPDATE ON tasks WHEN NEW.actual_completed_date IS NOT NULL BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
      );
      await expectLater(
        db.timeSessionDao.completeTimedSessionIfTargetReached(
          id,
          now: start.add(const Duration(minutes: 2)),
        ),
        throwsA(anything),
      );
      expect(
        (await (db.select(
          db.timeSessionTable,
        )..where((s) => s.id.equals(id))).getSingle()).status,
        'running',
      );
      expect((await db.taskDao.getTaskById(task))!.actualCompletedDate, isNull);
    },
  );
  test(
    'Foreground deadline completes a timed activity without pressing Finish',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final (task, id) = await session(
        at: DateTime.now().subtract(const Duration(seconds: 59)),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      try {
        container.read(timeTrackingProvider);
        await (db.select(db.taskTable)..where((t) => t.id.equals(task)))
            .watchSingle()
            .firstWhere((t) => t.actualCompletedDate != null)
            .timeout(const Duration(seconds: 4));
        expect(
          (await (db.select(
            db.timeSessionTable,
          )..where((s) => s.id.equals(id))).getSingle()).status,
          'completed',
        );
      } finally {
        container.dispose();
      }
    },
  );
  test(
    'Automatic deadline and manual session finish cannot double count a session',
    () async {
      final (task, id) = await session();
      final end = start.add(const Duration(seconds: 60));
      await Future.wait([
        () async {
          await db.timeSessionDao.completeTimedSessionIfTargetReached(
            id,
            now: end,
          );
        }(),
        () async {
          await db.timeSessionDao.completeSession(id, endedAt: end);
          await db.taskDao.completeTimedTaskAfterFocus(task);
        }(),
      ]);
      final row = (await db.taskDao.getTaskById(task))!;
      expect(row.actualMinutes, 1);
      expect(row.actualCompletedDate, isNotNull);
    },
  );
  test('An old deadline cannot complete a replaced workspace', () async {
    final (task, id) = await session();
    final revision = db.workspaceRevision;
    db.markWorkspaceReplaced();
    expect(
      await db.timeSessionDao.completeTimedSessionIfTargetReached(
        id,
        now: start.add(const Duration(minutes: 2)),
        expectedWorkspaceRevision: revision,
      ),
      false,
    );
    expect((await db.taskDao.getTaskById(task))!.actualCompletedDate, isNull);
  });
  test('Elapsed timer time cannot record a medicine dose as taken', () async {
    final medicine = await MedicineService(db, syncAlerts: false).addMedicine(
      name: 'Recorded schedule',
      dosage: 'User dose',
      scheduledTimes: ['10:00'],
      durationDays: 1,
      startDate: start,
    );
    final dose =
        (await db.medicineDao.watchLogsForMedicine(medicine).first).single;
    await db.taskDao.updateTask(
      TaskTableCompanion(
        id: drift.Value(dose.linkedTaskId!),
        estimatedMinutes: const drift.Value(1),
      ),
    );
    final id = await db.timeSessionDao.startSession(
      label: 'Recorded schedule',
      categoryId: category,
      linkedTaskId: dose.linkedTaskId,
      startedAt: start,
    );
    expect(
      await db.timeSessionDao.completeTimedSessionIfTargetReached(
        id,
        now: start.add(const Duration(minutes: 2)),
      ),
      false,
    );
    expect(
      (await db.medicineDao.watchLogsForMedicine(medicine).first)
          .single
          .isTaken,
      false,
    );
  });
}
