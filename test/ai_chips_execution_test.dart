import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/ai/ai_service.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Accelerator Chips & Prompt Execution Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'ascent_assistant_name': 'Riya',
      });
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Unload Thought chip prefills composer instead of blindly submitting', (tester) async {
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

      final unloadChip = find.text('Unload Thought');
      expect(unloadChip, findsOneWidget);

      await tester.tap(unloadChip);
      await tester.pump();

      // Should prefill the text field with "Save thought: "
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      final editable = tester.widget<TextField>(textField);
      expect(editable.controller?.text, 'Save thought: ');

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Sacred Promise chip prefills composer with "Create a promise to "', (tester) async {
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

      final promiseChip = find.text('Sacred Promise');
      expect(promiseChip, findsOneWidget);

      await tester.tap(promiseChip);
      await tester.pump();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      final editable = tester.widget<TextField>(textField);
      expect(editable.controller?.text, 'Create a promise to ');

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Engine: "Start chai break" routes to mindful reset with Open chai option', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final engine = LocalDeterministicAiEngine();
      final response = await engine.processUserPrompt('Start chai break', capturedRef);

      expect(response.text.contains('mindful reset') || response.text.contains('brewing guide'), isTrue);
      expect(response.clarifyingOptions, contains('Open chai'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Engine: "Check my walk status" returns encouraging walk summary', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final engine = LocalDeterministicAiEngine();
      final response = await engine.processUserPrompt('Check my walk status', capturedRef);

      expect(response.text.toLowerCase().contains('walk'), isTrue);
      expect(response.clarifyingOptions, contains('Log a walk'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Engine: Fallback response provides friendly, helpful language', (tester) async {
      late WidgetRef capturedRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final engine = LocalDeterministicAiEngine();
      final response = await engine.processUserPrompt('xyzabc nonexistent command 9999', capturedRef);

      expect(response.text.contains("didn't quite catch that"), isTrue);
      expect(response.clarifyingOptions, isNotEmpty);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
