import 'package:ascent/main.dart' as app;
import 'package:ascent/app/router.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Home restores Mind Space, recent collapse, four previews and saved-note actions',
    (tester) async {
      expect(
        (await PackageInfo.fromPlatform()).packageName,
        'com.arun.ascent.debug',
      );
      final prefs = await SharedPreferences.getInstance();
      for (final feature in [
        'Thought Wall',
        'Tasks & Today',
        'Medicine & Health',
      ]) {
        await prefs.setBool('feature_guide_v1_$feature', true);
      }
      await app.main();
      Future<void> until(Finder finder) async {
        for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(finder, findsAtLeastNWidgets(1));
      }

      await until(find.text('Start now'));
      await tester.tap(find.text('Start now'));
      await until(find.byType(HomeScreen));
      final db = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
        listen: false,
      ).read(databaseProvider);
      final ids = <int>[];
      for (var i = 0; i < 5; i++) {
        ids.insert(
          0,
          await db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(
              content: 'Device recent thought $i: one idea at a time.',
            ),
          ),
        );
      }
      await until(find.byKey(ValueKey('home_thought_${ids.first}')));
      expect(find.text('Quick capture'), findsNothing);
      expect(find.byType(ThoughtWallHomePreview), findsOneWidget);
      expect(find.byKey(ValueKey('home_thought_${ids[1]}')), findsNothing);
      expect(
        tester.getRect(find.byKey(const ValueKey('home_date'))).bottom,
        lessThan(
          tester.getRect(find.byKey(const ValueKey('home_header_actions'))).top,
        ),
      );
      expect(find.text('Customize Home'), findsOneWidget);
      expect(find.text('Mind Space'), findsNothing);
      await tester.tap(find.byKey(ValueKey('home_thought_${ids.first}')));
      await until(find.text('Thought Wall'));
      await until(find.byKey(ValueKey('thought_header_divider_${ids.first}')));
      expect(find.byType(BottomSheet), findsNothing);
      ascentRouter.go('/home');
      await until(find.byTooltip('Expand Mind Space'));
      await tester.ensureVisible(find.byTooltip('Expand Mind Space'));
      await tester.tap(find.byTooltip('Expand Mind Space'));
      await tester.pump(const Duration(milliseconds: 300));
      for (final id in ids.take(4)) {
        expect(find.byKey(ValueKey('home_thought_$id')), findsOneWidget);
      }
      expect(find.byKey(ValueKey('home_thought_${ids[4]}')), findsNothing);
      await tester.tap(find.byTooltip('Collapse Mind Space'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(ValueKey('home_thought_${ids[1]}')), findsNothing);
      await tester.enterText(
        find.byType(TextField).first,
        'Device Home thought to turn into a Todo',
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.ensureVisible(find.byTooltip('Send thought'));
      await tester.tap(find.byTooltip('Send thought'));
      await until(find.text('Todo'));
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
      await tester.ensureVisible(find.text('Todo'));
      await tester.tap(find.text('Todo'));
      await until(find.text('Save action'));
      expect(await db.select(db.taskTable).get(), isEmpty);
      await tester.tap(find.text('Save action'));
      for (
        var i = 0;
        i < 50 && (await db.select(db.taskTable).get()).isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(await db.select(db.taskTable).get(), hasLength(1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.text('View all'));
      await tester.tap(find.text('View all'));
      await until(find.byTooltip('Pin thought'));
      final borders = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .where(
            (d) => d.border is Border && (d.border! as Border).top.width == 1.2,
          );
      expect(borders, isNotEmpty);
      await tester.longPress(
        find.textContaining('Device Home thought to turn into a Todo'),
      );
      await until(find.byKey(const ValueKey('thought_selection_actions')));
      for (final label in ['Todo', 'Reminder', 'Both', 'Merge']) {
        expect(find.widgetWithText(ActionChip, label), findsOneWidget);
      }
      await tester.ensureVisible(
        find.textContaining('Device recent thought 4:'),
      );
      await tester.tap(find.textContaining('Device recent thought 4:'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.widgetWithText(ActionChip, 'Merge'));
      await until(find.text('Save merged note'));
      await tester.ensureVisible(find.text('Save merged note'));
      await tester.tap(find.text('Save merged note'));
      await until(find.byKey(const ValueKey('message_composer_send')));
      expect(
        find.byKey(const ValueKey('thought_selection_actions')),
        findsNothing,
      );
      expect(await db.thoughtDao.watchAllThoughts().first, hasLength(7));
      final timed = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Device timed activity',
          estimatedMinutes: const drift.Value(1),
        ),
      );
      ascentRouter.go('/today');
      await until(find.text('Device timed activity'));
      await tester.tap(find.text('Device timed activity'));
      await until(find.text('Open timer'));
      expect(find.text('Mark Done'), findsNothing);
      await tester.tap(find.text('Cancel'));
      ascentRouter.go('/home');
      await until(find.byType(HomeScreen));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
        listen: false,
      );
      container.read(timeTrackingProvider);
      final categories = await db.timeSessionDao.getAllCategories();
      final category =
          categories
              .where((c) => c.name.toLowerCase() == 'study')
              .firstOrNull
              ?.id ??
          await db.timeSessionDao.insertCategory(
            SessionCategoryTableCompanion.insert(
              name: 'Study',
              colorHex: '#5FA070',
            ),
          );
      await db.timeSessionDao.startSession(
        label: 'Device timed activity',
        categoryId: category,
        linkedTaskId: timed,
        startedAt: DateTime.now().subtract(const Duration(seconds: 59)),
      );
      for (
        var i = 0;
        i < 30 &&
            (await db.taskDao.getTaskById(timed))!.actualCompletedDate == null;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(
        (await db.taskDao.getTaskById(timed))!.actualCompletedDate,
        isNotNull,
      );
      ascentRouter.go('/home');
      await until(find.byTooltip('Expand Mind Space'));
      expect(find.byKey(ValueKey('home_thought_${ids.first}')), findsNothing);
      expect(tester.takeException(), isNull);
      debugPrint(
        'QA: Home note navigation, visible selection, merge exit, timer completion and revised Mind Space UI verified',
      );
    },
  );
}
