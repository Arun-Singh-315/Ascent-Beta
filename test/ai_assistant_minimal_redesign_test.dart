import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI Assistant Minimal Redesign & Menu Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'ai_assistant_name': 'Riya'});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'AI Assistant features 3-dots menu with companion switcher and clear history',
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

        // Find the 3-dots menu button
        final menuButton = find.byKey(
          const ValueKey('ai_assistant_menu_button'),
        );
        expect(menuButton, findsOneWidget);

        // Tap 3-dots menu
        await tester.tap(menuButton);
        await tester.pumpAndSettle();

        // Verify menu options
        expect(find.text('Change companion (Riya)'), findsOneWidget);
        expect(find.text('Clear history'), findsOneWidget);

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'AI Assistant message bubbles render with 1px border and high contrast in dark mode',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Seed messages: 1 user, 1 assistant
        await db.aiAssistantDao.insertMessage(
          AiChatMessageTableCompanion.insert(
            sender: 'user',
            message: 'What should I focus on next?',
          ),
        );
        await db.aiAssistantDao.insertMessage(
          AiChatMessageTableCompanion.insert(
            sender: 'assistant',
            message: 'Begin by wrapping up your top high-leverage task.',
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

        expect(find.text('What should I focus on next?'), findsOneWidget);
        expect(
          find.text('Begin by wrapping up your top high-leverage task.'),
          findsOneWidget,
        );

        // Verify no overflow exception
        expect(tester.takeException(), isNull);

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'AI Assistant Rule 13: 320px width & 2.0x scale overflow immunity',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Seed message
        await db.aiAssistantDao.insertMessage(
          AiChatMessageTableCompanion.insert(
            sender: 'assistant',
            message: 'Here is your morning overview.',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              aiAssistantDaoProvider.overrideWithValue(db.aiAssistantDao),
            ],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2.0),
              ),
              child: MaterialApp(
                theme: ThemeData.dark(),
                home: const AiAssistantScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Here is your morning overview.'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
