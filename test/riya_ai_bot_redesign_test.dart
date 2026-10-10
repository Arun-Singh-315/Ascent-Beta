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

  // Helper function to verify no emojis exist in a string
  bool hasAnyEmoji(String text) {
    final emojiRegex = RegExp(
      r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]',
      unicode: true,
    );
    return emojiRegex.hasMatch(text);
  }

  group('Riya AI Bot: Grounded Tone & Zero Emojis Tests', () {
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

    testWidgets('Expense response is professional, calm and has zero emojis', (tester) async {
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

      final response = await engine.processUserPrompt('spent 150 on coffee', widgetRef);
      expect(hasAnyEmoji(response.text), isFalse, reason: 'Response must contain zero emojis');
      expect(response.text, contains('₹150'));
    });

    testWidgets('Hydration response is clean and has zero emojis', (tester) async {
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

      final response = await engine.processUserPrompt('drank 250ml water', widgetRef);
      expect(hasAnyEmoji(response.text), isFalse, reason: 'Response must contain zero emojis');
      expect(response.text, contains('250 mL'));
    });

    testWidgets('Ambiguous activity clarification asks clear questions with zero emojis', (tester) async {
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

      final response = await engine.processUserPrompt('i want to exercise tomorrow', widgetRef);
      expect(hasAnyEmoji(response.text), isFalse, reason: 'Response must contain zero emojis');
      expect(response.clarifyingOptions, isNotEmpty);
      for (final option in response.clarifyingOptions) {
        expect(hasAnyEmoji(option), isFalse, reason: 'Quick option must contain zero emojis');
      }
    });

    testWidgets('Sleep schedule response is calming with zero emojis', (tester) async {
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

      final response = await engine.processUserPrompt('sleep by 11 pm', widgetRef);
      expect(hasAnyEmoji(response.text), isFalse, reason: 'Response must contain zero emojis');
      expect(response.text.toLowerCase(), contains('11:00 pm'));
    });

    testWidgets('Default companion overview provides grounded guidance with zero emojis', (tester) async {
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

      final response = await engine.processUserPrompt('hello', widgetRef);
      expect(hasAnyEmoji(response.text), isFalse, reason: 'Response must contain zero emojis');
    });

    testWidgets('Medicine schedule response formats as (medicine) without pill emoji', (tester) async {
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            medicineDaoProvider.overrideWithValue(db.medicineDao),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const SizedBox();
            },
          ),
        ),
      );

      final response = await tester.runAsync(() async {
        return await engine.processUserPrompt('What are my medicines today?', widgetRef);
      });
      expect(response, isNotNull);
      expect(hasAnyEmoji(response!.text), isFalse, reason: 'Response must contain zero emojis');
      expect(response.text, isNot(contains('💊')));
    });
  });

  group('Riya AI Bot: Chat UI Redesign & Bubble Tests', () {
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

    testWidgets('AiAssistantScreen renders atmospheric background, clean input, and emoji-free pills in dark mode', (tester) async {
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

      // WhatsApp style input bar: send button present, interior brain icon removed
      expect(find.byIcon(Icons.psychology_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      // Quick chips row (3 equal chips without horizontal scroll)
      expect(find.text('Plan my day'), findsWidgets);
      expect(find.text('Today\'s agenda'), findsOneWidget);
      expect(find.text('Medicines'), findsOneWidget);

      // Welcome prompt pills (clean text with zero emoji prefixes)
      expect(find.text('Plan my day'), findsWidgets);
      expect(find.text('Log 250ml water'), findsOneWidget);
      expect(find.text('What are my tasks today?'), findsOneWidget);

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
      expect(find.byIcon(Icons.psychology_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Clean unmount to drain Drift stream timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AiAssistantScreen hides pinned bottom suggestion chips when conversation has messages', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed an existing message in conversation
      await db.aiAssistantDao.insertMessage(
        AiChatMessageTableCompanion.insert(
          sender: 'assistant',
          message: 'Here is your agenda.',
        ),
      );

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

      // Pinned chips ("Today's agenda", "Medicines") must NOT be rendered when messages exist
      expect(find.text("Today's agenda"), findsNothing);
      expect(find.text('Medicines'), findsNothing);

      // Clean unmount to drain Drift stream timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
