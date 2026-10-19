import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/notifications/reminder_alert_sync.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/services/plan_service.dart';
import 'package:ascent/features/plans/planning_providers.dart';
import 'package:ascent/features/plans/widgets/plan_notification_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        planningAlertSyncProvider.overrideWith(
          (ref) => ReminderAlertSync(
            db,
            enabled: () async => true,
            reset: () async => true,
            cancel: (_) async => true,
            schedule: (_) async => true,
          ),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<(String, Reminder)> seed() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final date =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    final p = await PlanService(db).createPlan(
      title: 'Review architecture',
      startDate: date,
      endDate: date,
      localTime: '10:00',
    );
    final o = (await db.planDao.getOccurrencesForPlan(p.id)).single;
    return (
      o.id,
      (await db.reminderDao.getReminderById(
        (await db.planDao.getAlertLinksForOccurrence(o.id)).single.reminderId,
      ))!,
    );
  }

  Future<void> mount(
    WidgetTester t,
    (String, Reminder) target, {
    DateTime? snapshot,
    double scale = 1,
  }) async {
    t.view.physicalSize = const Size(320, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: PlanNotificationSheet(
              occurrenceId: target.$1,
              reminderId: target.$2.id,
              expectedAt: snapshot ?? target.$2.scheduledAt,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> flush(WidgetTester t) async {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
  }

  testWidgets(
    'notification opens exact activity and Done completes it and cancels alerts',
    (t) async {
      final target = await seed();
      await mount(t, target);
      expect(find.text('Review architecture'), findsOneWidget);
      await t.tap(find.text('Mark done'));
      await flush(t);
      expect((await db.planDao.getOccurrenceById(target.$1))!.outcome, 'done');
      expect(
        (await db.reminderDao.getReminderById(target.$2.id))!.isActive,
        isFalse,
      );
      expect(find.text('Mark done'), findsNothing);
      expect(find.textContaining('Remaining alerts'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'snooze changes one existing alert without completing or duplicating tasks',
    (t) async {
      final target = await seed();
      await mount(t, target);
      await t.tap(find.text('Remind me in 30 minutes'));
      await flush(t);
      final changed = (await db.reminderDao.getReminderById(target.$2.id))!;
      expect(
        changed.scheduledAt.difference(DateTime.now()).inMinutes,
        inInclusiveRange(29, 30),
      );
      expect((await db.select(db.reminderTable).get()).length, 1);
      expect(
        (await db.planDao.getOccurrenceById(target.$1))!.outcome,
        'scheduled',
      );
      expect(find.text('Remind me in 30 minutes'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'stale notification shows a useful warning and cannot mutate the item',
    (t) async {
      final target = await seed();
      await mount(
        t,
        target,
        snapshot: target.$2.scheduledAt.subtract(const Duration(minutes: 1)),
      );
      expect(find.textContaining('changed or turned off'), findsOneWidget);
      expect(find.text('Mark done'), findsNothing);
      expect(
        (await db.planDao.getOccurrenceById(target.$1))!.outcome,
        'scheduled',
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('a reminder cannot act on a different occurrence', (t) async {
    final first = await seed();
    final second = await seed();
    await mount(t, (first.$1, second.$2));
    expect(find.textContaining('changed or turned off'), findsOneWidget);
    expect(find.text('Mark done'), findsNothing);
    expect(find.text('Remind me in 30 minutes'), findsNothing);
    expect(
      (await db.planDao.getOccurrenceById(first.$1))!.outcome,
      'scheduled',
    );
    expect(
      (await db.planDao.getOccurrenceById(second.$1))!.outcome,
      'scheduled',
    );
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('notification details fit 320px and 2x text', (t) async {
    final target = await seed();
    await mount(t, target, scale: 2);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  test('notification destinations preserve the current reminder snapshot', () {
    const route =
        '/home?session=occ_plan_1_2027-01-01_0&reminder=12&at=1798797600000';
    expect(NotificationService.destinationForPayload(route), route);
    expect(NotificationService.destinationForPayload('$route&evil=1'), '/home');
  });
  test('replaying a snoozed notification is rejected', () async {
    final target = await seed();
    final service = PlanService(db);
    expect(
      await service.snoozeReminder(target.$2.id, target.$2.scheduledAt),
      isTrue,
    );
    expect(
      await service.snoozeReminder(target.$2.id, target.$2.scheduledAt),
      isFalse,
    );
    expect(
      await service.answerReminder(target.$2.id, target.$2.scheduledAt, 'done'),
      isFalse,
    );
  });
  test(
    'snoozing a repeated check-in leaves one future question, without a retry cascade',
    () async {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final plan = await PlanService(db).createPlan(
        title: 'Practice',
        startDate: date,
        endDate: date,
        localTime: '07:00',
        checkInPolicy: 'gentle',
      );
      final occurrence = (await db.planDao.getOccurrencesForPlan(
        plan.id,
      )).single;
      final links = await db.planDao.getAlertLinksForOccurrence(occurrence.id);
      final checks = links.where((l) => l.role == 'check_in').toList();
      final current = (await db.reminderDao.getReminderById(
        checks[1].reminderId,
      ))!;
      expect(
        await PlanService(db).snoozeReminder(current.id, current.scheduledAt),
        isTrue,
      );
      final reminders = await db.select(db.reminderTable).get();
      expect(
        reminders
            .where((r) => checks.any((l) => l.reminderId == r.id) && r.isActive)
            .length,
        1,
      );
      expect(
        (await db.reminderDao.getReminderById(
          current.id,
        ))!.scheduledAt.difference(DateTime.now()).inMinutes,
        inInclusiveRange(29, 30),
      );
    },
  );
}
