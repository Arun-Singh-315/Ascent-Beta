import 'package:ascent/core/providers/local_day_provider.dart';
import 'package:ascent/app/workspace_lifecycle.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/home_promise_section.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:ascent/features/promises/widgets/promise_detail_sheet.dart';
import 'package:ascent/features/vault/providers/vault_providers.dart';
import 'package:ascent/features/vault/services/vault_security_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuditClock extends LocalClock {
  @override
  DateTime build() => DateTime(2026, 11, 8);
  void advance() => state = state.add(const Duration(days: 1));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 15; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  test(
    'daily dismissals reload the new day without leaking yesterday IDs',
    () async {
      SharedPreferences.setMockInitialValues({
        'ascent_dismissed_today_activities_2026_11_8': ['lecture_7'],
        'ascent_dismissed_today_reminders_2026_11_8': ['3'],
      });
      final container = ProviderContainer(
        overrides: [
          localClockProvider.overrideWith(_AuditClock.new),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      expect(container.read(dismissedTodayActivityIdsProvider), {'lecture_7'});
      expect(container.read(dismissedTodayReminderIdsProvider), {3});
      (container.read(localClockProvider.notifier) as _AuditClock).advance();
      expect(container.read(dismissedTodayActivityIdsProvider), isEmpty);
      expect(container.read(dismissedTodayReminderIdsProvider), isEmpty);
      container.dispose();
    },
  );
  test(
    'Undo cannot reopen timed or lecture work, or an edited completion',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      for (final task in [
        TaskTableCompanion.insert(
          title: 'Timer',
          estimatedMinutes: const drift.Value(30),
        ),
        TaskTableCompanion.insert(
          title: 'Lecture',
          learningCourseId: const drift.Value('course'),
        ),
      ]) {
        final id = await db.taskDao.insertTask(task);
        expect(await db.taskDao.completeWithUndo(id), isNull);
        expect((await db.taskDao.getTaskById(id))!.actualCompletedDate, isNull);
      }
      final id = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Plain'),
      );
      final receipt = await db.taskDao.completeWithUndo(id);
      await (db.update(db.taskTable)..where((t) => t.id.equals(id))).write(
        TaskTableCompanion(
          actualCompletedDate: drift.Value(
            DateTime.now().add(const Duration(seconds: 1)),
          ),
        ),
      );
      expect(await db.taskDao.undoCompletion(receipt!), isFalse);
      await db.close();
    },
  );
  testWidgets('workspace lifecycle clears private unlocks and covers content', (
    t,
  ) async {
    final container = ProviderContainer();
    container.read(unlockedPromiseIdsProvider.notifier).unlock(8);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: WorkspaceLifecycle(
            child: Scaffold(body: Text('Private screen')),
          ),
        ),
      ),
    );
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await t.pump();
    expect(container.read(unlockedPromiseIdsProvider), isEmpty);
    expect(find.text('Private screen'), findsNothing);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    expect(container.read(unlockedPromiseIdsProvider), isEmpty);
    await t.pumpWidget(const SizedBox());
    container.dispose();
  });
  testWidgets(
    'locked Home commitment does not open details after failed authentication',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final repo = PromiseRepository(
        db,
        cancelNotification: (_) async {},
        scheduleNotification: (_, _, _, _) async => true,
      );
      await t.runAsync(
        () => repo.createPromise(
          title: 'AUDIT PRIVATE TITLE',
          intention: 'Audit only',
          category: 'personal',
          trackingType: PromiseTrackingType.completion,
          isPrivate: true,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          promiseRepositoryProvider.overrideWithValue(repo),
          vaultSecurityServiceProvider.overrideWithValue(
            VaultSecurityService.forTesting(mockBiometricsSuccess: false),
          ),
        ],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: HomePromiseSection()),
            ),
          ),
        ),
      );
      await flush(t);
      expect(find.text('AUDIT PRIVATE TITLE'), findsNothing);
      expect(container.read(unlockedPromiseIdsProvider), isEmpty);
      final card = find.byKey(const ValueKey('home_promise_card'));
      expect(card, findsOneWidget);
      await t.tapAt(t.getTopLeft(card) + const Offset(12, 12));
      await flush(t);
      expect(find.byType(PromiseDetailSheet), findsNothing);
      expect(find.text('AUDIT PRIVATE TITLE'), findsNothing);
      expect(container.read(unlockedPromiseIdsProvider), isEmpty);
      await t.pumpWidget(const SizedBox());
      await flush(t);
      await t.runAsync(() async {
        container.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await db.close();
      });
      await t.pump(const Duration(seconds: 1));
    },
  );
  test(
    'completion receipt reverses the matching completion and restores linked alerts',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final id = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Audit task'),
      );
      final reminder = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Alert',
          scheduledAt: DateTime.now().add(const Duration(hours: 1)),
          linkedTaskId: drift.Value(id),
        ),
      );
      final receipt = await db.taskDao.completeWithUndo(id);
      expect(receipt, isNotNull);
      expect(
        (await db.reminderDao.getReminderById(reminder))!.isActive,
        isFalse,
      );
      expect(await db.taskDao.undoCompletion(receipt!), isTrue);
      expect((await db.taskDao.getTaskById(id))!.actualCompletedDate, isNull);
      expect(
        (await db.reminderDao.getReminderById(reminder))!.isActive,
        isTrue,
      );
      expect(
        (await db.reminderDao.getReminderById(reminder))!.alertSyncPending,
        isTrue,
      );
      expect(await db.taskDao.undoCompletion(receipt), isFalse);
      await db.close();
    },
  );
  testWidgets(
    'Move to Tomorrow moves a standalone task and its linked reminder together',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());

      final now = DateTime.now();
      final at = DateTime(now.year, now.month, now.day, 20);
      final id = (await t.runAsync(
        () => db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Audit linked alert',
            plannedDate: drift.Value(at),
          ),
        ),
      ))!;
      final reminderId = (await t.runAsync(
        () => db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: 'Audit reminder',
            scheduledAt: at,
            linkedTaskId: drift.Value(id),
          ),
        ),
      ))!;
      final item = TodayActivityItem(
        id: 'task_$id',
        title: 'Audit linked alert',
        kind: ActivityKind.todo,
        status: TodayActivityStatus.notStarted,
        sourceType: 'task',
        categoryTag: 'Task',
        elapsedSecondsToday: 0,
        linkedTaskId: id,
        plannedDate: at,
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () => showActivityActions(context, ref, item),
                  child: const Text('Actions'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Actions'));
      await flush(t);
      await t.tap(find.text('Move to Tomorrow'));
      await flush(t);
      final task = await t.runAsync(() => db.taskDao.getTaskById(id));
      final reminder = await t.runAsync(
        () => db.reminderDao.getReminderById(reminderId),
      );
      expect(
        DateUtils.isSameDay(
          task!.plannedDate,
          DateTime(now.year, now.month, now.day + 1),
        ),
        isTrue,
      );
      expect(
        DateUtils.isSameDay(reminder!.scheduledAt, task.plannedDate),
        isTrue,
      );
      expect(reminder.scheduledAt.hour, at.hour);
      expect(reminder.alertSyncPending, isTrue);
      await t.pumpWidget(const SizedBox());
      await flush(t);
      await t.runAsync(() async {
        container.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await db.close();
      });
      await t.pump(const Duration(seconds: 1));
    },
  );
}
