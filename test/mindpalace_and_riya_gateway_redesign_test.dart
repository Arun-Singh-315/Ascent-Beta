import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/thought_wall/board/board_cards.dart';
import 'package:ascent/features/thought_wall/thought_wall_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'assistant_name': 'Riya'});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDownAll(() async {
    await db.close();
  });

  Widget buildApp(Widget child, {double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    );
  }

  group('Ask Riya Gateway & Mindspace Alignment Tests', () {
    testWidgets(
      'HomeHeader remains spacious without an assistant hero',
      (tester) async {
        await tester.pumpWidget(
          buildApp(
            const Scaffold(
              body: HomeHeader(profile: null),
            ),
          ),
        );
        await tester.pump();

        // HomeHeader does not contain home_assistant_button
        expect(
          find.descendant(
            of: find.byType(HomeHeader),
            matching: find.byKey(const ValueKey('home_assistant_button')),
          ),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );


  });

  group('Mind Palace Style & Typography Tests', () {

    testWidgets('ThoughtWallAppearance bubbleFilled defaults to false', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final appearance = container.read(thoughtWallAppearanceProvider);
      expect(appearance.bubbleFilled, false);
    });

    testWidgets('BoardCard renders reflective text and styling in Mind Palace', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 17, 12, 0);
      final thought = Thought(
        id: 1,
        content:
            'Long reflective paragraph describing creative thoughts and quiet focus for Ascent.',
        category: 'general',
        mood: 'idea',
        colorHex: '#000000',
        createdAt: now,
        isPinned: true,
        isArchived: false,
        isCompleted: false,
      );

      await tester.pumpWidget(
        buildApp(
          Scaffold(
            body: BoardCard(thought: thought, index: 0, now: now),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Long reflective paragraph'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

  });
}
