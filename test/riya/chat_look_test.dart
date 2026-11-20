import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/chat_palette.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'chat: user bubble tinted, reply unboxed, fits 320 px (dark=$dark, x$scale)',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          await tester.runAsync(() async {
            await db.aiAssistantDao.insertMessage(
              AiChatMessageTableCompanion.insert(
                sender: 'user',
                message: 'What tasks do I have today?',
              ),
            );
            await db.aiAssistantDao.insertMessage(
              AiChatMessageTableCompanion.insert(
                sender: 'assistant',
                message: 'You have **two** things today.',
              ),
            );
          });
          tester.view.physicalSize = const Size(320, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                sharedPreferencesProvider.overrideWithValue(prefs),
                aiAssistantDaoProvider.overrideWithValue(db.aiAssistantDao),
              ],
              child: MaterialApp(
                theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const AiAssistantScreen(compact: true),
              ),
            ),
          );
          for (var i = 0; i < 6; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pump(const Duration(milliseconds: 200));
          }
          final palette = dark ? ChatPalette.dark : ChatPalette.light;
          final fills = tester
              .widgetList<Container>(find.byType(Container))
              .map((c) => (c.decoration as BoxDecoration?)?.color)
              .whereType<Color>()
              .toList();
          expect(fills, contains(palette.userBubble));
          expect(find.text('What tasks do I have today?'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        },
      );
    }
  }
}
