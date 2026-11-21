import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/ai/ai_service.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Accelerator Chips & Prompt Execution Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'ascent_assistant_name': 'Riya'});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });



    testWidgets(
      'Engine: "spent ₹150 on coffee" returns proposed expense action',
      (tester) async {
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
        final response = await engine.processUserPrompt(
          'spent ₹150 on coffee',
          capturedRef,
        );

        expect(response.proposedAction, isNotNull);
        expect(response.proposedAction!.type, AiActionType.expenseLogged);
        expect(response.text.contains('150'), isTrue);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Engine: Fallback response provides friendly, helpful language',
      (tester) async {
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
        final response = await engine.processUserPrompt(
          'xyzabc nonexistent command 9999',
          capturedRef,
        );

        expect(response.text.contains("didn't quite catch that"), isTrue);
        expect(response.clarifyingOptions, isNotEmpty);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
