import 'dart:async';
import 'package:ascent/main.dart' as app;
import 'package:ascent/app/router.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/notifications/reminder_alert_sync.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:ascent/features/thought_wall/thought_actions.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Mind Space UI, connected actions, learning, layout and real native alerts',
    (tester) async {
      expect(
        (await PackageInfo.fromPlatform()).packageName,
        'com.arun.ascent.debug',
      );
      final prefs = await SharedPreferences.getInstance();
      for (final feature in ['Thought Wall', 'Tasks & Today', 'Focus Timer']) {
        await prefs.setBool('feature_guide_v1_$feature', true);
      }
      await app.main();
      Future<void> until(Finder finder) async {
        for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(finder, findsAtLeastNWidgets(1));
      }

      await until(find.text('Start now'));
      await tester.tap(find.text('Start now'));
      await until(find.byType(HomeScreen));
      await tester.pump(const Duration(seconds: 1));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
        listen: false,
      );
      final db = container.read(databaseProvider);
      final learning = container.read(learningHubProvider.notifier);
      await learning.ready;
      for (
        var attempt = 0;
        attempt < 30 &&
            !await NotificationService.instance.areNotificationsEnabled();
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(
        await NotificationService.instance.areNotificationsEnabled(),
        true,
      );
      debugPrint('QA: native permission ready');
      await tester.enterText(
        find.byType(TextField).first,
        'Device QA: capture this idea before it escapes.',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byTooltip('Send thought'));
      await tester.tap(find.byTooltip('Send thought'));
      await tester.pump(const Duration(seconds: 1));
      final notes = await db.thoughtDao.watchAllThoughts().first;
      final note = notes.singleWhere((n) => n.content.startsWith('Device QA:'));
      expect(find.text('Todo'), findsAtLeastNWidgets(1));
      debugPrint('QA: Home capture and saved-only action chips verified');
      ascentRouter.go('/thought-wall');
      await until(find.byTooltip('Pin thought'));
      await tester.tap(find.byTooltip('Pin thought').first);
      await tester.pump(const Duration(milliseconds: 500));
      expect((await db.thoughtDao.getThoughtById(note.id))!.isPinned, true);
      expect(
        find.byKey(ValueKey('thought_header_divider_${note.id}')),
        findsOneWidget,
      );
      debugPrint('QA: native Thought Wall pin and divider rendered');
      final current = (await db.thoughtDao.getThoughtById(note.id))!;
      final at = DateTime.now().add(const Duration(hours: 1));
      final converted = await ThoughtActions(
        db,
      ).convert([current], mode: ThoughtConversionMode.both, at: at);
      final replay = await ThoughtActions(
        db,
      ).convert([current], mode: ThoughtConversionMode.both, at: at);
      expect(converted.taskIds, replay.taskIds);
      expect(converted.reminders.single.id, replay.reminders.single.id);
      final alert = await ReminderAlertSync.device(
        db,
      ).sync(ids: [converted.reminders.single.id]);
      expect(alert.complete, true);
      expect(await db.taskDao.markComplete(converted.taskIds.single), true);
      await ReminderAlertSync.device(db).sync(onlyPending: true);
      expect(
        (await db.reminderDao.getReminderById(
          converted.reminders.single.id,
        ))!.isActive,
        false,
      );
      debugPrint(
        'QA: Both persisted once; native schedule and completion cancellation verified',
      );
      final course = container.read(learningHubProvider).course;
      final planned = await learning.saveLectureActivity(
        requestId: 'device-qa-lecture',
        courseId: course.id,
        moduleId: course.modules.first.id,
        plannedDate: DateTime.now(),
        title: 'Device QA lecture',
        durationSeconds: 60,
        thresholdPercent: 50,
      );
      expect(
        await learning.markLectureCompleted(planned.id, courseId: course.id),
        false,
      );
      final received = Completer<List<TodayActivityItem>>();
      final subscription = container.listen(todayActivitiesProvider, (
        _,
        value,
      ) {
        if (value.hasValue &&
            value.value!.any(
              (item) =>
                  item.learningCourseId == course.id &&
                  item.learningLectureId == planned.id,
            ) &&
            !received.isCompleted) {
          received.complete(value.value!);
        }
        if (value.hasError && !received.isCompleted) {
          received.completeError(value.error!, value.stackTrace);
        }
      }, fireImmediately: true);
      final activities = await received.future.timeout(
        const Duration(seconds: 10),
      );
      subscription.close();
      expect(
        activities.any(
          (item) =>
              item.learningCourseId == course.id &&
              item.learningLectureId == planned.id,
        ),
        true,
      );
      final layout = container.read(homeLayoutProvider);
      await container
          .read(homeLayoutProvider.notifier)
          .save(layout.copyWith(visible: {}));
      ascentRouter.go('/home');
      await until(find.byType(HomeScreen));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byTooltip('Send thought'), findsOneWidget);
      expect(find.text('Your Home'), findsNothing);
      debugPrint('QA: all-hidden Home keeps quick capture accessible');
      final result = await RiyaExecutor(db).execute(
        const RiyaCommand('reminders.list', {}),
        requestId: 'device-qa-read',
      );
      expect(result.message, contains('Today'));
      final money = RiyaExecutor(db);
      final income = await money.execute(
        const RiyaCommand('transactions.create', {
          'title': 'Device QA salary',
          'amount': 2500,
          'type': 'income',
        }),
        requestId: 'device-qa-income',
        approved: true,
      );
      ascentRouter.go('/money');
      await until(find.text('Device QA salary'));
      expect(await db.financeDao.watchTodaySpending().first, 0);
      await money.execute(
        RiyaCommand('transactions.edit', {
          'id': income.entityId!,
          'title': 'Device QA corrected salary',
          'account': 'Cash',
        }),
        requestId: 'device-qa-income-edit',
        approved: true,
      );
      await until(find.text('Device QA corrected salary'));
      final savedIncome = await money.execute(
        RiyaCommand('transactions.read', {'id': income.entityId!}),
        requestId: 'device-qa-income-read',
      );
      expect(savedIncome.message, contains('Cash'));
      await money.execute(
        RiyaCommand('transactions.delete', {'id': income.entityId!}),
        requestId: 'device-qa-income-delete',
        approved: true,
      );
      await until(find.text('No Transactions Yet'));
      debugPrint(
        'QA: native Money reflects bot income creation, correction and deletion',
      );
      expect(tester.takeException(), isNull);
      debugPrint('QA: Mind Space native device suite passed');
    },
  );
}
