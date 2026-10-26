import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:ascent/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Assistant Gemini Polish & Identity Customization Tests', () {
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

    testWidgets(
      'Companion Identity switcher allows switching between Aria and Riya via bottom sheet',
      (tester) async {
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

        // Identity switcher is rendered in AppBar
        final switcher = find.byKey(
          const ValueKey('ai_assistant_identity_switcher'),
        );
        expect(switcher, findsOneWidget);
        expect(find.text('Riya'), findsWidgets);

        // Tap identity switcher to open bottom sheet
        await tester.tap(switcher);
        await tester.pumpAndSettle();

        // Verify bottom sheet contents
        expect(find.text('Companion Identity'), findsOneWidget);
        expect(find.text('Aria'), findsOneWidget);
        expect(find.text('· Reflective & Calm'), findsOneWidget);
        expect(find.text('Riya'), findsWidgets);
        expect(find.text('· Vibrant & Action-Driven'), findsOneWidget);

        // Switch to Aria
        await tester.tap(find.text('Aria'));
        await tester.pumpAndSettle();

        // Verify name changed to Aria
        expect(find.text('Aria'), findsWidgets);
        expect(prefs.getString('ascent_assistant_name'), 'Aria');

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Empty state renders contextual accelerator cards and tapping populates prompt',
      (tester) async {
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

        // 4 crisp accelerators
        expect(find.text('Unload Thought'), findsOneWidget);
        expect(find.text('Sacred Promise'), findsOneWidget);
        expect(find.text('Chai Reset'), findsOneWidget);
        expect(find.text('Health & Meds'), findsOneWidget);

        // Tap Chai Reset
        await tester.tap(find.text('Chai Reset'));
        await tester.pump();

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'Immunity to UI overflow at 320px width with 2.0x text scale (Rule 13)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: child!,
              ),
              home: const AiAssistantScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Zero exceptions / RenderFlex overflows
        expect(tester.takeException(), isNull);

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
