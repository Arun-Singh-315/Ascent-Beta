import 'dart:io';

import 'package:ascent/app/app.dart';
import 'package:ascent/app/router.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/daily_briefing_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/daily_briefing_card.dart';
import 'package:ascent/features/today/add_activity_sheet.dart';
import 'package:ascent/features/today/task_board_screen.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:ascent/shared/widgets/thought_excerpt.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'daily welcome and existing routes work on Android with isolated records',
    (tester) async {
      expect(
        (await PackageInfo.fromPlatform()).packageName,
        'com.arun.ascent.qa',
      );
      GoogleFonts.config.allowRuntimeFetching = false;
      // No production database or real preference values are read or changed.
      SharedPreferences.setMockInitialValues({
        'ascent_quick_start_v1': true,
        'ascent_day_one_tutorial_v2_dismissed': true,
        'ascent_theme_mode': 'light',
        for (final feature in [
          'Thought Wall',
          'Tasks & Today',
          'Riya',
          'Medicine & Health',
          'Focus Timer',
        ])
          'feature_guide_v1_$feature': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      Future<void> until(Finder finder) async {
        for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(finder, findsAtLeastNWidgets(1));
      }

      Future<void> tap(Finder finder) async {
        await until(finder);
        await tester.ensureVisible(finder);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(finder);
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<void> snapshot(String name) async {
        await tester.pump(const Duration(milliseconds: 400));
        final bytes = await binding.takeScreenshot(name);
        final cache = await getTemporaryDirectory();
        await File('${cache.path}/$name.png').writeAsBytes(bytes, flush: true);
        debugPrint('QA screenshot: ${cache.path}/$name.png');
        expect(tester.takeException(), isNull);
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AscentApp(),
        ),
      );
      await until(find.byType(HomeScreen));
      await until(find.byTooltip('Dismiss daily briefing'));
      await binding.convertFlutterSurfaceToImage();
      await snapshot('briefing_empty');
      await tap(find.text('Plan one small task').last);
      await until(find.byType(AddActivitySheet));
      expect(
        identical(
          ProviderScope.containerOf(
            tester.element(find.byType(AddActivitySheet)),
            listen: false,
          ).read(databaseProvider),
          db,
        ),
        isTrue,
      );
      await tester.enterText(
        find
            .descendant(
              of: find.byType(AddActivitySheet),
              matching: find.byType(TextField),
            )
            .first,
        'Take a ten minute walk',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 300));
      await snapshot('task_composer');
      await tap(find.text('Create Activity'));
      await snapshot('task_saved');
      for (
        var i = 0;
        i < 40 && (await db.taskDao.watchAllTasks().first).isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(
        (await db.taskDao.watchAllTasks().first).single.title,
        'Take a ten minute walk',
      );
      await until(find.text('Take me to my tasks'));
      await snapshot('briefing_home');
      await tap(find.text('Take me to my tasks'));
      await until(find.byType(TaskBoardScreen));
      expect(find.text('Take a ten minute walk'), findsAtLeastNWidgets(1));
      ascentRouter.go('/home');
      await until(find.byType(DailyBriefingCard));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byTooltip('Dismiss daily briefing'), findsNothing);

      final now = DateTime.now();
      final day = briefingDay(now);
      final yesterday = DateTime(day.year, day.month, day.day - 1);
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Yesterday completed task',
          plannedDate: drift.Value(yesterday),
          actualCompletedDate: drift.Value(
            yesterday.add(const Duration(hours: 12)),
          ),
        ),
      );
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Reschedule this unfinished task',
          plannedDate: drift.Value(yesterday),
        ),
      );
      await tap(find.text('Open daily check-in'));
      await until(find.textContaining('1 overdue task needs'));
      await snapshot('briefing_recorded');
      await tap(find.byTooltip('Dismiss daily briefing'));
      final note = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content:
              '--> Positive start\n--> No junk food\n--> Make room for a walk\n--> One small step is enough',
        ),
      );
      await until(find.byKey(ValueKey('home_thought_$note')));
      final excerpt = find.descendant(
        of: find.byKey(ValueKey('home_thought_$note')),
        matching: find.byType(ThoughtExcerpt),
      );
      await tap(find.descendant(of: excerpt, matching: find.text('Read more')));
      expect(
        find.descendant(of: excerpt, matching: find.text('Read less')),
        findsOneWidget,
      );
      expect(
        ascentRouter.routerDelegate.currentConfiguration.uri.path,
        '/home',
      );
      await snapshot('thought_expanded');
      await tap(find.descendant(of: excerpt, matching: find.text('Read less')));
      await tester.scrollUntilVisible(
        find.text('Open daily check-in'),
        -240,
        scrollable: find
            .descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tap(find.text('Open daily check-in'));
      await tap(find.text('Capture a thought').last);
      await until(find.byType(ThoughtWallScreen));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
      ascentRouter.go('/home');
      await until(find.text('Ask Riya'));
      await tap(find.text('Ask Riya'));
      await until(find.byType(AiAssistantScreen));
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .any(
              (field) =>
                  field.controller?.text.contains(
                    'Ask how I am feeling first.',
                  ) ??
                  false,
            ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      ascentRouter.go('/home');
      await until(find.byType(HomeScreen));
      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pump(const Duration(milliseconds: 600));
      await tap(find.text('Open daily check-in'));
      await snapshot('briefing_dark');
      await tap(find.byTooltip('Dismiss daily briefing'));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pump(const Duration(milliseconds: 500));
      await tap(find.text('Open daily check-in'));
      await snapshot('briefing_large_text');
      await tap(find.byTooltip('Dismiss daily briefing'));
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      for (final route in [
        '/reminders',
        '/money',
        '/more',
        '/today',
        '/learning',
        '/home',
      ]) {
        ascentRouter.go(route);
        await tester.pump(const Duration(milliseconds: 700));
        expect(
          ascentRouter.routerDelegate.currentConfiguration.uri.path,
          route,
        );
        expect(tester.takeException(), isNull, reason: 'Existing route $route');
      }
      debugPrint(
        'QA: daily popup, task creation, live summary, inline read more/less, thoughts, Riya draft, themes and existing routes verified on Android',
      );
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump(Duration.zero);
      await db.close();
    },
  );
}
