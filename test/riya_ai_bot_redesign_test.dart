import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/ai/ai_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:ascent/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Riya AI Bot: Tone & Emojis Unit Tests', () {
    final engine = LocalDeterministicAiEngine();

    testWidgets('Expense response contains warm tone and emojis (💸, ✨)', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final response = await engine.processUserPrompt('spent 150 on coffee', widgetRef);
      expect(response.text, contains('💸'));
      expect(response.text, contains('✨'));
      expect(response.text, contains('₹150'));
    });

    testWidgets('Hydration response contains energizing emojis (💧, 🌊)', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final response = await engine.processUserPrompt('drank 250ml water', widgetRef);
      expect(response.text, contains('💧'));
      expect(response.text, contains('🌊'));
      expect(response.text, contains('250 mL'));
    });

    testWidgets('Ambiguous activity clarification asks friendly questions with emojis (🎯, ⏱️)', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final response = await engine.processUserPrompt('i want to exercise tomorrow', widgetRef);
      expect(response.text, contains('🎯'));
      expect(response.text, contains('⏱️'));
      expect(response.clarifyingOptions, isNotEmpty);
    });

    testWidgets('Sleep schedule response contains soothing emojis (🌙, 💤)', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final response = await engine.processUserPrompt('sleep by 11 pm', widgetRef);
      expect(response.text, contains('🌙'));
      expect(response.text, contains('💤'));
    });

    testWidgets('Default companion overview provides warm emojis (🌸, ✨, 🎯, 🚀)', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final response = await engine.processUserPrompt('hello', widgetRef);
      expect(response.text, contains('🌸'));
      expect(response.text, contains('✨'));
      expect(response.text, contains('🎯'));
      expect(response.text, contains('🚀'));
    });
  });

  group('Riya AI Bot: Chat UI Redesign & Background Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'ai_assistant_name': 'Riya',
      });
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('AiAssistantScreen renders atmospheric background and WhatsApp input in dark mode', (tester) async {
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
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const AiAssistantScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header components
      expect(find.text('Riya'), findsWidgets);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);

      // WhatsApp style input bar
      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      // Quick chips row (3 equal chips without horizontal scroll)
      expect(find.text('Plan my day'), findsWidgets);
      expect(find.text('Today\'s agenda'), findsOneWidget);
      expect(find.text('Medicines'), findsOneWidget);

      // Welcome prompt pills
      expect(find.text('⚡ Plan my day'), findsOneWidget);
      expect(find.text('💧 Log 250ml water'), findsOneWidget);
      expect(find.text('🎯 What are my tasks today?'), findsOneWidget);

      // Clean unmount to drain Drift stream timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AiAssistantScreen renders beautifully in light (day) mode without overflow', (tester) async {
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
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const AiAssistantScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Riya'), findsWidgets);
      expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Clean unmount to drain Drift stream timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
