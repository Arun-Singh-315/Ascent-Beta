import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/ai/ai_service.dart';
import 'package:ascent/app/router.dart';
import 'package:go_router/go_router.dart';
import 'package:ascent/features/momentum/momentum_onboarding_screen.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MedicineService medicineService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    medicineService = MedicineService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Medicine Feature & Multi-Day Auto-Sync Tests', () {
    test('addMedicine automatically schedules doses, tasks, and reminders across all days', () async {
      final startDate = DateTime(2026, 10, 10);
      const durationDays = 5;
      final timings = ['08:00', '20:00']; // 2 doses per day

      final medId = await medicineService.addMedicine(
        name: 'Amoxicillin 500mg',
        dosage: '1 Capsule',
        scheduledTimes: timings,
        durationDays: durationDays,
        startDate: startDate,
        instructions: 'After meal',
        type: 'capsule',
      );

      expect(medId, isPositive);

      // Verify medicine record
      final med = await db.medicineDao.getMedicineById(medId);
      expect(med, isNotNull);
      expect(med!.name, 'Amoxicillin 500mg');
      expect(med.durationDays, 5);

      // Verify medicine logs created: 5 days * 2 timings = 10 logs
      final allLogs = await db.medicineDao.watchLogsForMedicine(medId).first;
      expect(allLogs.length, 10);

      // Verify all 10 tasks created in TaskTable
      final allTasks = await db.taskDao.watchAllTasks().first;
      expect(allTasks.length, 10);
      for (final task in allTasks) {
        expect(task.title, contains('Amoxicillin 500mg (medicine)'));
        expect(task.priority, 'high');
        expect(task.estimatedMinutes, isNull); // Rule 9: simple to-do, no timer
        expect(task.actualCompletedDate, isNull);
      }

      // Verify all 10 reminders created in ReminderTable
      final allReminders = await db.reminderDao.watchAllReminders().first;
      expect(allReminders.length, 10);
      for (final r in allReminders) {
        expect(r.title, contains('Amoxicillin 500mg'));
        expect(r.linkedTaskId, isNotNull);
      }
    });

    test('Bi-directional sync: checking dose in Medicine marks linked task complete and vice versa', () async {
      final today = DateTime.now();
      final startDate = DateTime(today.year, today.month, today.day);

      final medId = await medicineService.addMedicine(
        name: 'Paracetamol 500mg',
        dosage: '1 Tablet',
        scheduledTimes: ['08:00'],
        durationDays: 1,
        startDate: startDate,
        instructions: 'After food',
      );

      final logs = await db.medicineDao.watchLogsForMedicine(medId).first;
      expect(logs.length, 1);
      final log = logs.first;
      final linkedTaskId = log.linkedTaskId!;

      // 1. Initially both are incomplete
      expect(log.isTaken, isFalse);
      final initialTask = await db.taskDao.getTaskById(linkedTaskId);
      expect(initialTask!.actualCompletedDate, isNull);

      // 2. Mark dose taken via MedicineService -> Linked task should complete
      await medicineService.toggleDose(log.id, true);
      final updatedLog = (await db.medicineDao.watchLogsForMedicine(medId).first).first;
      expect(updatedLog.isTaken, isTrue);

      final completedTask = await db.taskDao.getTaskById(linkedTaskId);
      expect(completedTask!.actualCompletedDate, isNotNull);

      // 3. Uncomplete task from taskDao -> Linked dose should revert to pending
      await db.taskDao.toggleTaskCompletion(linkedTaskId, false);
      final revertedLog = (await db.medicineDao.watchLogsForMedicine(medId).first).first;
      expect(revertedLog.isTaken, isFalse);

      // 4. Complete task from taskDao -> Linked dose should update to taken
      await db.taskDao.toggleTaskCompletion(linkedTaskId, true);
      final reCompletedLog = (await db.medicineDao.watchLogsForMedicine(medId).first).first;
      expect(reCompletedLog.isTaken, isTrue);
    });

    test('Cascading Deletion (Rule 8): Deleting medicine cleanly removes all reminders, tasks, and logs', () async {
      final startDate = DateTime(2026, 10, 10);
      final medId = await medicineService.addMedicine(
        name: 'Thyronorm 50mcg',
        dosage: '1 Tablet',
        scheduledTimes: ['07:00'],
        durationDays: 7,
        startDate: startDate,
        instructions: 'Empty stomach',
      );

      // Verify entities exist
      expect((await db.medicineDao.watchLogsForMedicine(medId).first).length, 7);
      expect((await db.taskDao.watchAllTasks().first).length, 7);
      expect((await db.reminderDao.watchAllReminders().first).length, 7);

      // Delete medicine
      await medicineService.deleteMedicine(medId);

      // Zero orphans guarantee
      expect(await db.medicineDao.getMedicineById(medId), isNull);
      expect((await db.medicineDao.watchLogsForMedicine(medId).first).isEmpty, isTrue);
      expect((await db.taskDao.watchAllTasks().first).isEmpty, isTrue);
      expect((await db.reminderDao.watchAllReminders().first).isEmpty, isTrue);
    });
  });

  group('Router Resolution & Page Not Found Exception Fix Tests', () {
    bool hasRoute(List<dynamic> routes, String target) {
      for (final r in routes) {
        if (r is GoRoute) {
          if (r.path == target) return true;
          if (r.routes.isNotEmpty && hasRoute(r.routes, target)) return true;
        } else if (r is StatefulShellRoute) {
          for (final branch in r.branches) {
            if (hasRoute(branch.routes, target)) return true;
          }
        } else if (r is ShellRoute) {
          if (hasRoute(r.routes, target)) return true;
        }
      }
      return false;
    }

    test('Router registers /momentum-onboarding route cleanly', () {
      expect(hasRoute(ascentRouter.configuration.routes, AscentRoutes.momentumOnboarding), isTrue);
    });

    test('Router registers /momentum/onboarding alias route cleanly', () {
      expect(hasRoute(ascentRouter.configuration.routes, AscentRoutes.momentumOnboardingAlt), isTrue);
    });

    test('Router registers /medicine route cleanly', () {
      expect(hasRoute(ascentRouter.configuration.routes, AscentRoutes.medicine), isTrue);
    });

    testWidgets('MomentumOnboardingScreen renders without throwing GoException', (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_complete': true});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: MomentumOnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Momentum'), findsOneWidget);
      expect(find.text('Personalized protocol assessment'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('MedicineScreen renders cleanly with schedule and prescription controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            medicineDaoProvider.overrideWithValue(db.medicineDao),
            medicineServiceProvider.overrideWithValue(medicineService),
          ],
          child: const MaterialApp(
            home: MedicineScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Medicine & Health'), findsOneWidget);
      expect(find.text('Prescriptions & Dose Reminders'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('AI Assistant Medicine Integration Tests', () {
    testWidgets('Riya handles medicine queries and reports dose compliance', (tester) async {
      final today = DateTime.now();
      final startDate = DateTime(today.year, today.month, today.day);

      // Add a test medicine for today
      await medicineService.addMedicine(
        name: 'Vitamin C 500mg',
        dosage: '1 Chewable Tab',
        scheduledTimes: ['09:00', '21:00'],
        durationDays: 3,
        startDate: startDate,
      );

      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            medicineDaoProvider.overrideWithValue(db.medicineDao),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      late AiResponse response;
      await tester.runAsync(() async {
        final engine = LocalDeterministicAiEngine();
        response = await engine.processUserPrompt('What are my medicines today?', widgetRef);
      });

      expect(response.text, contains('Vitamin C 500mg'));
      expect(response.text, contains('Pending'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Riya reports empty guidance when no medicines scheduled', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            medicineDaoProvider.overrideWithValue(db.medicineDao),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pump();

      late AiResponse response;
      await tester.runAsync(() async {
        final engine = LocalDeterministicAiEngine();
        response = await engine.processUserPrompt('Show my medicines', widgetRef);
      });

      expect(response.text, contains("don't have any active prescriptions"));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
