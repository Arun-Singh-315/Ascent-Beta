import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:ascent/features/ai_assistant/assistant_suggestions.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          aiAssistantDaoProvider.overrideWithValue(db.aiAssistantDao),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const AiAssistantScreen(),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
  }

  Finder tiles() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('ai_suggestion_'),
  );

  testWidgets('suggestions are a 2x2 grid on a phone', (tester) async {
    await pump(tester);
    final rects = tiles()
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    expect(rects, hasLength(4));
    expect(rects[0].top, rects[1].top);
    expect(rects[1].left, greaterThan(rects[0].right));
    expect(rects[2].top, greaterThan(rects[0].bottom));
    await unmount(tester);
  });

  testWidgets('one column at 2x text, with no overflow', (tester) async {
    await pump(tester, scale: 2);
    final rects = tiles()
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    expect(rects[1].top, greaterThan(rects[0].bottom));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('regenerate shows only under the latest reply', (tester) async {
    for (final (who, text) in [
      ('user', 'Hi'),
      ('assistant', 'Hello! How can I help?'),
      ('user', 'Plan my day'),
      ('assistant', 'Here is your plan.'),
    ]) {
      await db.aiAssistantDao.insertMessage(
        AiChatMessageTableCompanion.insert(sender: who, message: text),
      );
    }
    await pump(tester);
    expect(find.byTooltip('Regenerate'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsNWidgets(2));
    await unmount(tester);
  });

  test('every suggestion has a fitting icon', () {
    for (final hour in [8, 14, 19, 23]) {
      for (final s in assistantSuggestions(DateTime(2026, 1, 1, hour))) {
        expect(assistantSuggestionIcon(s), isA<IconData>());
      }
    }
    expect(
      assistantSuggestionIcon('Log 250ml water'),
      Icons.water_drop_outlined,
    );
  });
}
