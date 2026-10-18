import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ascent/core/services/home_capture_service.dart';
import 'package:ascent/core/services/plan_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/plan_collection_service.dart';

void main() {
  late AppDatabase db;
  late PlanCollectionService service;
  final now = DateTime(2026, 10, 18, 9);
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = PlanCollectionService(db, clock: () => now);
  });
  tearDown(() => db.close());
  test(
    'list markers become independent rows without splitting prose arrows',
    () {
      expect(
        PlanItemDraft.parseList('list:\n-- Java\n--> RAG\n3. Apply\n• Read'),
        ['Java', 'RAG', 'Apply', 'Read'],
      );
      expect(
        PlanItemDraft.parseList(
          '-- wake up early\n-- gym\n-- need to focus\n--Avoid food',
        ),
        ['wake up early', 'gym', 'need to focus', 'Avoid food'],
      );
      expect(PlanItemDraft.parseList('A -> B is an example.'), [
        'A -> B is an example.',
      ]);
    },
  );
  test('independent plans and idempotent saves preserve every item', () async {
    final items = [
      const PlanItemDraft(title: 'Java'),
      const PlanItemDraft(title: 'RAG'),
    ];
    final a = await service.save(
      title: 'Preparation',
      items: items,
      requestId: 'a',
    );
    final retry = await service.save(
      title: 'Preparation',
      items: items,
      requestId: 'a',
    );
    final b = await service.save(
      title: 'Preparation',
      items: items,
      requestId: 'b',
    );
    expect(retry, a);
    expect(b, isNot(a));
    final views = await service.watchCollections().first;
    expect(views.length, 2);
    expect(views.every((v) => v.total == 2 && v.done == 0), isTrue);
    final rows = await service.watchItems(a).first;
    await service.complete(rows.first, true);
    expect(
      (await service.watchCollections().first)
          .firstWhere((v) => v.id == a)
          .done,
      1,
    );
    expect(
      (await service.watchCollections().first)
          .firstWhere((v) => v.id == b)
          .done,
      0,
    );
  });
  test(
    'mixed schedules create only requested alerts and completion cancels start',
    () async {
      final id = await service.save(
        title: 'Mixed',
        requestId: 'mixed',
        items: [
          const PlanItemDraft(title: 'Unscheduled'),
          PlanItemDraft(
            title: 'Quiet',
            at: now.add(const Duration(days: 1)),
            alert: 'none',
          ),
          PlanItemDraft(
            title: 'Alarm',
            at: now.add(const Duration(days: 1, hours: 2)),
            alert: 'alarm',
          ),
        ],
      );
      var rows = await service.watchItems(id).first;
      expect(rows.length, 3);
      expect((await db.reminderDao.watchAllReminders().first).length, 1);
      expect(
        (await db.reminderDao.watchAllReminders().first).single.alarmEnabled,
        isTrue,
      );
      await service.complete(rows.firstWhere((r) => r.title == 'Alarm'), true);
      expect(
        (await db.reminderDao.watchAllReminders().first).single.isActive,
        isFalse,
      );
      expect(
        (await db.reminderDao.watchAllReminders().first)
            .single
            .alertSyncPending,
        isTrue,
      );
    },
  );
  test('invalid batch rolls back and past alerts are rejected', () async {
    await expectLater(
      service.save(
        title: 'Invalid',
        requestId: 'bad',
        items: [
          const PlanItemDraft(title: 'Good'),
          const PlanItemDraft(title: ''),
        ],
      ),
      throwsArgumentError,
    );
    expect(await service.watchCollections().first, isEmpty);
    await expectLater(
      service.save(
        title: 'Past',
        requestId: 'past',
        items: [
          PlanItemDraft(
            title: 'Past',
            at: now.subtract(const Duration(hours: 1)),
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
  test(
    'pause/resume/delete preserve durable cancellations and remove owned tasks',
    () async {
      final id = await service.save(
        title: 'Lifecycle',
        requestId: 'life',
        items: [
          PlanItemDraft(title: 'Alert', at: now.add(const Duration(days: 1))),
        ],
      );
      await service.setStatus(id, 'paused');
      expect(
        (await db.reminderDao.watchAllReminders().first).single.isActive,
        isFalse,
      );
      await service.setStatus(id, 'active');
      expect(
        (await db.reminderDao.watchAllReminders().first).single.isActive,
        isTrue,
      );
      await service.deleteCollection(id);
      expect(await service.watchCollections().first, isEmpty);
      expect(await db.taskDao.watchAllTasks().first, isEmpty);
      final alert = (await db.reminderDao.watchAllReminders().first).single;
      expect(alert.isActive, isFalse);
      expect(alert.alertSyncPending, isTrue);
    },
  );
  test(
    '100 items remain independent and progress follows task completion',
    () async {
      final id = await service.save(
        title: 'Large',
        requestId: 'large',
        items: List.generate(100, (i) => PlanItemDraft(title: 'Item $i')),
      );
      final rows = await service.watchItems(id).first;
      await db.taskDao.toggleTaskCompletion(rows[50].taskId!, true);
      final summary = (await service.watchCollections().first).single;
      expect(summary.total, 100);
      expect(summary.done, 1);
    },
  );
  test('append retries never duplicate items', () async {
    final id = await service.save(
      title: 'A',
      requestId: 'create',
      items: [const PlanItemDraft(title: 'First')],
    );
    for (var n = 0; n < 2; n++) {
      await service.save(
        title: 'A',
        collectionId: id,
        requestId: 'append',
        items: [const PlanItemDraft(title: 'Second')],
      );
    }
    expect((await service.watchItems(id).first).length, 2);
  });
  test(
    'editing a routine preserves past completion and its item identity',
    () async {
      final id = await service.save(
        title: 'Routine',
        requestId: 'routine',
        items: [
          PlanItemDraft(
            title: 'Read',
            at: now.add(const Duration(hours: 1)),
            recurrence: 'daily',
            endDate: now.add(const Duration(days: 3)),
          ),
        ],
      );
      final before = (await service.watchItems(id).first).single;
      await service.complete(before, true);
      final done = (await service.watchItems(id).first).single;
      await service.updateItem(
        done,
        PlanItemDraft(
          title: 'Read more',
          at: now.add(const Duration(days: 1, hours: 2)),
          recurrence: 'daily',
          endDate: now.add(const Duration(days: 4)),
        ),
      );
      final after = (await service.watchItems(id).first).single;
      expect(after.id, before.id);
      final history = await db.planDao.getOccurrencesForPlan(
        after.definitionId!,
      );
      expect(history.where((o) => o.outcome == 'done').length, 1);
      expect(history.where((o) => o.outcome == 'scheduled').length, 4);
      await service.importLegacy();
      expect((await service.watchCollections().first).length, 1);
    },
  );
  test(
    'old notification actions cannot complete moved schedules or paused plans',
    () async {
      final id = await service.save(
        title: 'Alerts',
        requestId: 'alerts',
        items: [
          PlanItemDraft(
            title: 'Read',
            at: now.add(const Duration(days: 1)),
            checkIn: true,
          ),
        ],
      );
      final item = (await service.watchItems(id).first).single;
      final occurrence = (await db.planDao.getOccurrencesForPlan(
        item.definitionId!,
      )).single;
      final links = await db.planDao.getAlertLinksForOccurrence(occurrence.id);
      final link = links.firstWhere((l) => l.role == 'check_in');
      final reminder = (await db.reminderDao.getReminderById(link.reminderId))!;
      final plans = PlanService(db, clock: () => now);
      await service.setStatus(id, 'paused');
      expect(
        await plans.answerReminder(reminder.id, reminder.scheduledAt, 'done'),
        isFalse,
      );
      await service.setStatus(id, 'active');
      await service.updateItem(
        item,
        PlanItemDraft(title: 'Read', at: now.add(const Duration(days: 2))),
      );
      expect(
        await plans.answerReminder(reminder.id, reminder.scheduledAt, 'done'),
        isFalse,
      );
      expect((await service.watchCollections().first).single.done, 0);
    },
  );
  test(
    'legacy import preserves task and reminder IDs and does not resurrect deleted plans',
    () async {
      final thoughtId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Read'),
      );
      final source = (await db.thoughtDao.getThoughtById(thoughtId))!;
      final old = await HomeCaptureService(db, clock: () => now).schedule(
        source: source,
        title: 'Read',
        at: now.add(const Duration(days: 1)),
      );
      await service.importLegacy();
      await service.importLegacy();
      final collections = await service.watchCollections().first;
      expect(collections.length, 1);
      final item =
          (await service.watchItems(collections.single.id).first).single;
      expect(item.taskId, old.task!.id);
      expect(
        (await db.reminderDao.watchAllReminders().first).single.id,
        old.reminder.id,
      );
      await service.deleteCollection(collections.single.id);
      await service.importLegacy();
      expect(await service.watchCollections().first, isEmpty);
      expect(await db.thoughtDao.getThoughtById(thoughtId), isNotNull);
    },
  );
  test(
    'source note survives item completion and multiple plans share provenance',
    () async {
      final thoughtId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: '-- Read\n-- Apply'),
      );
      for (final key in ['first', 'second']) {
        await service.save(
          title: key,
          requestId: key,
          sourceThoughtId: thoughtId,
          items: [const PlanItemDraft(title: 'Read')],
        );
      }
      final plan = (await service.watchCollections().first).first;
      await service.complete(
        (await service.watchItems(plan.id).first).single,
        true,
      );
      expect(
        (await db.thoughtDao.getThoughtById(thoughtId))!.isCompleted,
        isFalse,
      );
      expect((await service.watchCollections().first).length, 2);
    },
  );
  test('task deletion cannot leave a phantom item in an active plan', () async {
    final id = await service.save(
      title: 'Protected',
      requestId: 'protected',
      items: [const PlanItemDraft(title: 'Keep me')],
    );
    final item = (await service.watchItems(id).first).single;
    final restriction = await db.taskDao.getTaskProtection(item.taskId!);
    expect(restriction, isNotNull);
  });

  test('date-only items appear on their day without creating alerts', () async {
    final id = await service.save(
      title: 'Today',
      requestId: 'date',
      items: [
        PlanItemDraft(
          title: 'Read',
          at: DateTime(now.year, now.month, now.day),
          dateOnly: true,
        ),
      ],
    );
    final item = (await service.watchItems(id).first).single;
    expect(item.dateOnly, isTrue);
    expect(item.at, DateTime(now.year, now.month, now.day));
    expect(await db.reminderDao.watchAllReminders().first, isEmpty);
    expect((await db.taskDao.watchTasksByDate(now).first).single.title, 'Read');
  });
  test(
    'batch schedule keeps item identities and rejects partial saves',
    () async {
      final id = await service.save(
        title: 'Batch',
        requestId: 'batch',
        items: [
          const PlanItemDraft(title: 'A'),
          const PlanItemDraft(title: 'B'),
        ],
      );
      final rows = await service.watchItems(id).first;
      await expectLater(
        service.updateItems(rows, [
          PlanItemDraft(title: 'A', at: now.add(const Duration(days: 1))),
          const PlanItemDraft(title: ''),
        ]),
        throwsArgumentError,
      );
      expect(
        (await service.watchItems(id).first).every((i) => i.at == null),
        isTrue,
      );
      await service.updateItems(rows, [
        PlanItemDraft(title: 'A', at: now.add(const Duration(days: 1))),
        PlanItemDraft(
          title: 'B',
          at: now.add(const Duration(days: 1, hours: 1)),
        ),
      ]);
      expect(
        (await service.watchItems(id).first).map((i) => i.id),
        rows.map((i) => i.id),
      );
      expect((await db.reminderDao.watchAllReminders().first).length, 2);
    },
  );
  test(
    'user scenario: thought with routine items parses, customizes with different reminders, and preserves thought',
    () async {
      // 1. User records a thought containing 4 checklist items
      const thoughtText =
          '-- wake up early\n-- gym\n-- need to focus\n--Avoid food';
      final thoughtId = await db.into(db.thoughtTable).insert(
        ThoughtTableCompanion.insert(
          content: thoughtText,
          mood: const Value('thought'),
        ),
      );

      // 2. Parser identifies the 4 independent items
      final parsed = PlanItemDraft.parseList(thoughtText);
      expect(parsed, [
        'wake up early',
        'gym',
        'need to focus',
        'Avoid food',
      ]);

      // 3. User customizes each item in the plan editor with different reminders
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final customizedItems = [
        PlanItemDraft(
          title: parsed[0], // wake up early
          at: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 6, 0),
          alert: 'alarm',
        ),
        PlanItemDraft(
          title: parsed[1], // gym
          at: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 7, 30),
          minutes: 45,
          alert: 'reminder',
        ),
        PlanItemDraft(
          title: parsed[2], // need to focus
          at: DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0),
          minutes: 120,
          checkIn: true,
          alert: 'reminder',
        ),
        PlanItemDraft(
          title: parsed[3], // Avoid food
          at: tomorrow,
          dateOnly: true,
          alert: 'none',
        ),
      ];

      // 4. Save the plan collection linked to the source thought
      final planId = await service.save(
        title: 'Daily Routine & Focus',
        sourceThoughtId: thoughtId,
        requestId: 'daily_routine_test',
        items: customizedItems,
      );

      // 5. Original thought remains intact in database
      final storedThought = await db.thoughtDao.getThoughtById(thoughtId);
      expect(storedThought, isNotNull);
      expect(storedThought!.content, thoughtText);

      // 6. Plan collection has 4 items with their custom configuration
      final items = await service.watchItems(planId).first;
      expect(items.length, 4);
      expect(items[0].title, 'wake up early');
      expect(items[0].alert, 'alarm');
      expect(
        items[0].at,
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 6, 0),
      );

      expect(items[1].title, 'gym');
      expect(items[1].alert, 'reminder');
      expect(items[1].minutes, 45);

      expect(items[2].title, 'need to focus');
      expect(items[2].checkIn, isTrue);
      expect(items[2].minutes, 120);

      expect(items[3].title, 'Avoid food');
      expect(items[3].dateOnly, isTrue);
      expect(items[3].alert, 'none');

      // 7. Verify device alerts: only the timed items get scheduled alerts.
      // 'wake up early' has 1 alarm, 'gym' has 1 reminder, and 'need to focus' has 2 (start alert + follow-up check-in).
      // 'Avoid food' is date-only with 0 alerts.
      final alerts = await db.reminderDao.watchAllReminders().first;
      expect(alerts.length, 4);
      final wakeAlert = alerts.firstWhere(
        (a) => a.title.contains('wake up early'),
      );
      expect(wakeAlert.alarmEnabled, isTrue); // Alarm alert
      expect(wakeAlert.isActive, isTrue);
      expect(
        wakeAlert.scheduledAt,
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 6, 0),
      );

      // 8. Individual completion: completing to-do item 'wake up early' marks it done and deactivates its alarm
      final wakeItem = items.firstWhere((i) => i.title == 'wake up early');
      await service.complete(wakeItem, true);

      final updatedCollection = (await service.watchCollections().first)
          .firstWhere((c) => c.id == planId);
      expect(updatedCollection.done, 1);
      expect(updatedCollection.total, 4);

      // Verify item views
      final updatedItems = await service.watchItems(planId).first;
      expect(
        updatedItems.firstWhere((i) => i.title == 'wake up early').done,
        isTrue,
      );
      expect(updatedItems.firstWhere((i) => i.title == 'gym').done, isFalse);

      // Wake up early alarm is deactivated
      final updatedAlerts = await db.reminderDao.watchAllReminders().first;
      final wakeAlertAfter = updatedAlerts.firstWhere(
        (a) => a.title.contains('wake up early'),
      );
      expect(wakeAlertAfter.isActive, isFalse);

      // Gym and focus alerts remain active
      final gymAlert = updatedAlerts.firstWhere((a) => a.title.contains('gym'));
      expect(gymAlert.isActive, isTrue);
    },
  );
}
