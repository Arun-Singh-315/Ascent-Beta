import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/reminder_actions.dart';
import 'package:ascent/core/services/home_capture_service.dart';
import 'package:ascent/core/services/plan_child_protection.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final at = DateTime(2030, 1, 1, 9);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  Future<int> insert() => db.reminderDao.insertReminder(
    ReminderTableCompanion.insert(title: 'Review', scheduledAt: at),
  );

  test(
    'completion and snooze retain retriable intent when device sync fails',
    () async {
      final id = await insert();
      final actions = ReminderActions(
        db,
        sync: (_) async => throw StateError('offline'),
      );
      final original = await actions.complete(id);
      var saved = (await db.reminderDao.getReminderById(id))!;
      expect(saved.isActive, false);
      expect(saved.alertSyncPending, true);
      expect(await actions.undoCompletion(original!), true);
      saved = (await db.reminderDao.getReminderById(id))!;
      expect(saved.isActive, true);
      await actions.complete(id);
      await actions.snooze(id, at.add(const Duration(minutes: 10)));
      expect(await actions.undoCompletion(original), false);
      saved = (await db.reminderDao.getReminderById(id))!;
      expect(saved.scheduledAt, at.add(const Duration(minutes: 10)));
      expect(saved.isActive, true);
    },
  );

  test(
    'completion Undo never reactivates an alert after its task was finished',
    () async {
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Linked task'),
      );
      final reminderId = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Linked reminder',
          scheduledAt: at,
          linkedTaskId: drift.Value(taskId),
        ),
      );
      final actions = ReminderActions(db);
      final before = await actions.complete(reminderId);
      await db.taskDao.markComplete(taskId);
      expect(await actions.undoCompletion(before!), false);
      expect(
        (await db.reminderDao.getReminderById(reminderId))!.isActive,
        false,
      );
    },
  );

  test(
    'clearing chat keeps pending alert effects and never resurrects messages',
    () async {
      final userId = await db.aiAssistantDao.insertMessage(
        AiChatMessageTableCompanion.insert(
          sender: 'user',
          message: 'Save an alert',
        ),
      );
      final result = await RiyaExecutor(db).execute(
        RiyaCommand('reminders.create', {
          'title': 'Pending alert',
          'at': at.toIso8601String(),
        }),
        requestId: 'chat:$userId',
        approved: true,
      );
      await db.aiAssistantDao.clearChatHistory();
      expect(await db.select(db.aiCommandTable).get(), hasLength(1));
      expect(await db.reminderDao.getReminderById(result.entityId!), isNotNull);
      await db.aiAssistantDao.recoverCommandResponses();
      expect(await db.aiAssistantDao.watchRecentMessages().first, isEmpty);
    },
  );

  test('delete and undo preserve identity and thought links', () async {
    final id = await insert();
    final thoughtId = await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(content: 'Source'),
    );
    await db
        .into(db.thoughtReminderLinkTable)
        .insert(
          ThoughtReminderLinkTableCompanion.insert(
            thoughtId: thoughtId,
            reminderId: id,
          ),
        );
    final row = (await db.reminderDao.getReminderById(id))!;
    final actions = ReminderActions(db);
    await actions.delete(id);
    expect(await db.reminderDao.getReminderById(id), isNull);
    expect(await actions.restoreDeleted(row), true);
    expect(await db.reminderDao.getLinkedThoughtIds(id), [thoughtId]);
    expect(await actions.restoreDeleted(row), false);
  });

  test(
    'plan deletion remains protected and clearing chat preserves plan receipts',
    () async {
      final sourceId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Plan'),
      );
      final source = (await db.thoughtDao.getThoughtById(sourceId))!;
      final plan = await HomeCaptureService(
        db,
      ).schedule(source: source, title: 'Plan', at: at);
      final rows = await db.reminderDao.watchAllReminders().first;
      final id = rows.single.id;
      await db.aiAssistantDao.clearChatHistory();
      expect(await db.reminderDao.getReminderProtection(id), isNotNull);
      await expectLater(
        ReminderActions(db).delete(id),
        throwsA(isA<PlanChildProtectionException>()),
      );
      expect(
        (await HomeCaptureService(db).plans()).single.requestId,
        plan.requestId,
      );
    },
  );
}
