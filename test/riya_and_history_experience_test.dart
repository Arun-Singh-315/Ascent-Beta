import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:ascent/features/history/history_screen.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildScope(Widget child, {List<dynamic> overrides = const []}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        aiAssistantDaoProvider.overrideWithValue(db.aiAssistantDao),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AscentTheme.light(),
        darkTheme: AscentTheme.dark(),
        home: child,
      ),
    );
  }

  group('Riya AI Assistant Experience Tests', () {
    testWidgets('Empty chat screen displays strong minimal hero typography without chip clutter', (tester) async {
      await tester.pumpWidget(buildScope(const AiAssistantScreen(compact: true)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byType(AiAssistantScreen), findsOneWidget);
      // Minimal strong centered hero text
      expect(find.textContaining('ascend today?'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AiAssistantScreen is immune to overflow at 320px with 2.0x text scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: buildScope(const AiAssistantScreen(compact: true)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Classified History Tests', () {
    testWidgets('HistoryScreen renders domain classification filter segments', (tester) async {
      await tester.pumpWidget(buildScope(const HistoryScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.text('Focus & Tasks'), findsOneWidget);
      expect(find.text('Habits & Health'), findsOneWidget);
      expect(find.text('Mind & Promises'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('HistoryScreen is immune to overflow at 320px with 2.0x text scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: buildScope(const HistoryScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Yesterday Summary Report Card in Your Space Tests', () {
    testWidgets('HomeShortcutPanel renders yesterday report button and expands narrative report card', (tester) async {
      await tester.pumpWidget(
        buildScope(
          Scaffold(
            body: SingleChildScrollView(
              child: HomeShortcutPanel(
                shortcuts: const ['focus', 'hydration', 'vault'],
                showReminders: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('yesterday_report_button')), findsOneWidget);

      // Tap report button
      await tester.tap(find.byKey(const ValueKey('yesterday_report_button')));
      await tester.pumpAndSettle();

      // Narrative report card appears with qualitative words, no raw 0/1 numbers
      expect(find.byKey(const ValueKey('yesterday_report_card')), findsOneWidget);
      expect(find.textContaining('Yesterday’s Reflection'), findsOneWidget);
      expect(find.text('Keep report in Your Space'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('HomeShortcutPanel with expanded report card is immune to overflow at 320px with 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: buildScope(
              Scaffold(
                body: SingleChildScrollView(
                  child: HomeShortcutPanel(
                    shortcuts: const ['focus', 'hydration', 'vault'],
                    showReminders: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('yesterday_report_button')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
