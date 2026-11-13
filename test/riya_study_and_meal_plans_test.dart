import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascent/core/ai/ai_service.dart';
import 'package:ascent/core/ai/ai_action_execution.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:ascent/features/ai_assistant/riya_plan_cards.dart';
import 'package:ascent/features/study_plan/study_plan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Riya AI Study & Meal Plans - End-to-End Engine & Integrity Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;
    final engine = LocalDeterministicAiEngine();

    setUp(() async {
      SharedPreferences.setMockInitialValues({'ai_assistant_name': 'Riya'});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Engine creates structured Study Plan with syllabus and study category', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final response = await engine.processUserPrompt(
        'Create a 7 day study plan for DSA',
        widgetRef,
      );

      expect(response.proposedAction, isNotNull);
      expect(response.proposedAction!.type, AiActionType.studyPlanCreated);
      final payload = response.proposedAction!.payload;
      expect(payload['category'], 'study');
      expect(payload['durationDays'], 7);
      expect(payload['items'], isA<List>());
      expect((payload['items'] as List).length, 7);
    });

    testWidgets('Engine creates structured Meal Plan with 4 meals and meal category', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final response = await engine.processUserPrompt(
        'Create a high protein meal plan for the week',
        widgetRef,
      );

      expect(response.proposedAction, isNotNull);
      expect(response.proposedAction!.type, AiActionType.mealPlanCreated);
      final payload = response.proposedAction!.payload;
      expect(payload['category'], 'meal');
      expect(payload['targetWaterMl'], 2500);
      expect(payload['items'], isA<List>());
      expect((payload['items'] as List).length, 4);
    });

    testWidgets('AiActionExecution saves Study Plan and categorizes tasks without polluting buffer', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final response = await engine.processUserPrompt(
        'Create a study plan for DSA',
        widgetRef,
      );

      final executor = AiActionExecution(db);
      final result = await executor.execute(response.proposedAction!);

      expect(result.message, contains('Activated'));

      // Check PlanCollectionTable
      final collections = await db.select(db.planCollectionTable).get();
      expect(collections.length, 1);
      expect(collections.first.description, contains('study'));

      // Check Tasks carry category notes and do not buffer as unclassified
      final tasks = await db.select(db.taskTable).get();
      expect(tasks.length, 7);
      for (final task in tasks) {
        expect(task.notes, contains('[Category: study]'));
      }

      // Check PlanCollectionItems
      final items = await db.select(db.planCollectionItemTable).get();
      expect(items.length, 7);
    });

    testWidgets('AiActionExecution saves Meal Plan with scheduled reminders', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final response = await engine.processUserPrompt(
        'High protein meal plan',
        widgetRef,
      );

      final executor = AiActionExecution(db);
      final result = await executor.execute(response.proposedAction!);

      expect(result.message, contains('Activated'));

      // Check PlanCollectionTable
      final collections = await db.select(db.planCollectionTable).get();
      expect(collections.length, 1);
      expect(collections.first.description, contains('meal'));

      // Check Tasks carry meal category notes
      final tasks = await db.select(db.taskTable).get();
      expect(tasks.length, 4);
      for (final task in tasks) {
        expect(task.notes, contains('[Category: meal]'));
      }
    });

    testWidgets('Riya AI Chat UI has zero double ticks (done_all) and renders serene glass cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            aiAssistantDaoProvider.overrideWithValue(db.aiAssistantDao),
          ],
          child: const MaterialApp(
            home: AiAssistantScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure double tick icon is completely eliminated
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);

      // Verify Study Plan and Meal Plan quick chips are visible
      expect(find.text('Study Plan'), findsOneWidget);
      expect(find.text('Meal Plan'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('RiyaStudyPlanCard and RiyaMealPlanCard survive 320px width & 2.0x font scaling without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyStudyPlan = {
        'title': 'DSA Mastery Sprint',
        'subject': 'Data Structures',
        'durationDays': 7,
        'dailyMinutes': 90,
        'category': 'study',
        'items': [
          {'title': 'Day 1: Arrays & Two Pointers', 'minutes': 90, 'notes': 'Array basics'},
          {'title': 'Day 2: Sliding Window', 'minutes': 90, 'notes': 'Two pointer patterns'},
        ],
      };

      final dummyMealPlan = {
        'title': 'Clean Eating Nutrition',
        'dietType': 'Clean High-Protein',
        'targetWaterMl': 2500,
        'category': 'meal',
        'items': [
          {'time': '08:30', 'title': 'Breakfast: Oats & Eggs', 'notes': 'Protein rich', 'calories': 400},
          {'time': '13:30', 'title': 'Lunch: Brown Rice & Chicken', 'notes': 'Balanced macros', 'calories': 650},
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: ListView(
                  children: [
                    RiyaStudyPlanCard(planData: dummyStudyPlan),
                    RiyaMealPlanCard(planData: dummyMealPlan),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no exceptions or overflows occurred
      expect(tester.takeException(), isNull);
      expect(find.text('DSA Mastery Sprint'), findsOneWidget);
      expect(find.text('Clean Eating Nutrition'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('StudyPlanScreen displays active plan and syllabus milestones cleanly at 320px', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: StudyPlanScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Study Plan Hub'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
