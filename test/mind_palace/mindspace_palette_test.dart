import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/thought_wall/board/thought_board_screen.dart';
import 'package:ascent/features/thought_wall/board/board_background.dart';
import 'package:ascent/features/thought_wall/board/board_cards.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/mindspace_palette.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const ThoughtBoardScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('empty built-in spaces stay hidden; used ones show', (
    tester,
  ) async {
    await tester.runAsync(
      () => db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Fix the login flicker',
          category: const Value('bugs'),
        ),
      ),
    );
    await pump(tester);
    expect(find.byKey(const ValueKey('space_chip_bugs')), findsOneWidget);
    expect(find.byKey(const ValueKey('space_chip_suggestions')), findsNothing);
    expect(find.byKey(const ValueKey('space_chip_life_goals')), findsNothing);
    expect(find.byKey(const ValueKey('space_chip_new')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('the board sits on the plain app canvas', (tester) async {
    await pump(tester);
    final box = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(BoardBackground),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(box.color, AscentGlass.light.bg);
    await unmount(tester);
  });

  test('a space keeps one colour; moods keep theirs', () {
    Thought t(int id, {String cat = 'general', String mood = 'thought'}) =>
        Thought(
          id: id,
          content: 'x',
          mood: mood,
          category: cat,
          colorHex: '#000000',
          isPinned: false,
          isArchived: false,
          isCompleted: false,
          createdAt: DateTime(2026),
        );
    const g = AscentGlass.light;
    expect(
      boardAccentFor(g, t(1, cat: 'custom_3')),
      boardAccentFor(g, t(2, cat: 'custom_3')),
    );
    expect(
      boardAccentFor(g, t(1, cat: 'custom_3')),
      spaceAccentFor(g, 'custom_3'),
    );
    expect(
      boardAccentFor(g, t(5, mood: 'idea')),
      MindspacePalette.amber(false),
    );
    expect(
      boardAccentFor(AscentGlass.dark, t(5, mood: 'idea')),
      MindspacePalette.amber(true),
    );
  });
}
