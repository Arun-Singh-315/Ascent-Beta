import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/study_plan/study_plan_screen.dart';

void main() {
  setUpAll(() async {
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ]) {
      GoogleFonts.plusJakartaSans(fontWeight: weight);
      GoogleFonts.jetBrainsMono(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  });

  group('Study Plan Companion & Intelligent Pacing Tests', () {
    testWidgets('Study Plan renders Daily Pacing, Next Focus Target, and Daily Study Reminder Card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // Seed a study plan
      const planId = 'study-plan-algo-101';
      await db.into(db.planCollectionTable).insert(
        PlanCollectionTableCompanion.insert(
          id: planId,
          requestId: 'req-study-1',
          title: 'Data Structures & Algorithms',
          description: const drift.Value('Comprehensive study plan for tech interviews'),
        ),
      );

      // Seed 2 tasks and items
      final task1Id = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Arrays & Two Pointers',
          estimatedMinutes: const drift.Value(45),
        ),
      );
      final task2Id = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Binary Search & Sliding Window',
          estimatedMinutes: const drift.Value(60),
        ),
      );

      await db.into(db.planCollectionItemTable).insert(
        PlanCollectionItemTableCompanion.insert(
          id: 'item-1',
          collectionId: planId,
          title: 'Arrays & Two Pointers',
          notes: const drift.Value('Master left/right pointer patterns'),
          position: 0,
          taskId: drift.Value(task1Id),
        ),
      );
      await db.into(db.planCollectionItemTable).insert(
        PlanCollectionItemTableCompanion.insert(
          id: 'item-2',
          collectionId: planId,
          title: 'Binary Search & Sliding Window',
          notes: const drift.Value('Focus on boundary conditions'),
          position: 1,
          taskId: drift.Value(task2Id),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: const StudyPlanScreen(),
          ),
        ),
      );

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);

      // Verify study companion elements render
      expect(find.text('Data Structures & Algorithms'), findsWidgets);
      expect(find.textContaining('Today\'s Study Focus'), findsOneWidget);
      expect(find.textContaining('Arrays & Two Pointers'), findsWidgets);

      final reminderFinder = find.textContaining('Daily Study Reminder');
      await tester.scrollUntilVisible(
        reminderFinder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(reminderFinder, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('Toggling Daily Study Reminder schedules reminder alert in database', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const planId = 'study-plan-sysdesign';
      await db.into(db.planCollectionTable).insert(
        PlanCollectionTableCompanion.insert(
          id: planId,
          requestId: 'req-study-2',
          title: 'System Design Masterclass',
          description: const drift.Value('Study system architectures'),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const StudyPlanScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the switch or button for study reminder
      final reminderSwitch = find.byKey(const ValueKey('study_reminder_switch'));
      await tester.scrollUntilVisible(
        reminderSwitch,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(reminderSwitch, findsOneWidget);

      // Tap to activate daily reminder
      await tester.tap(reminderSwitch);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify a reminder with title containing Study was inserted
      final reminders = await tester.runAsync(
        () => db.reminderDao.watchAllReminders().first,
      );
      expect(reminders!.any((r) => r.title.contains('Study')), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
