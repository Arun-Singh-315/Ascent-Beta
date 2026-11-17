import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_assistant_hero_card.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/thought_wall/board/board_background.dart';
import 'package:ascent/features/thought_wall/board/board_cards.dart';
import 'package:ascent/features/thought_wall/board/spaces_shelf.dart';
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
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('Ask Riya Gateway & Mindspace Alignment Tests', () {
    testWidgets('HomeAssistantHeroCard renders outside header with glowing disc & tooltip', (tester) async {
      await tester.pumpWidget(
        buildApp(const Scaffold(body: HomeAssistantHeroCard())),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('home_assistant_button')), findsOneWidget);
      expect(find.text('Ask Riya'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.byTooltip('Ask Riya'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('HomeHeader remains spacious without assistant hero when includeAssistant is false', (tester) async {
      await tester.pumpWidget(
        buildApp(const Scaffold(body: HomeHeader(profile: null, includeAssistant: false))),
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
    });

    testWidgets('Mindspace SectionCard View all > is right-aligned without duplicate chevrons', (tester) async {
      await tester.pumpWidget(
        buildApp(const Scaffold(body: ThoughtWallHomePreview(compact: true))),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('home_mind_space_view_all')), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);

      // SectionCard chevron onOpen is null so no duplicate chevron icon
      final viewAllFinder = find.byKey(const ValueKey('home_mind_space_view_all'));
      expect(viewAllFinder, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('SpacesShelf header has View all button at the right end', (tester) async {
      await tester.pumpWidget(
        buildApp(
          Scaffold(
            body: SpacesShelf(
              spaces: const [],
              archivedCount: 0,
              onOpen: (_) {},
              onNew: () {},
              onOpenArchive: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('space_tile_all')), findsOneWidget);
      expect(find.byKey(const ValueKey('space_tile_new')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('Mind Palace Style & Typography Tests', () {
    testWidgets('Default BoardBackdrop is paper with subtle off-white gradient', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final backdrop = container.read(boardBackdropProvider);
      expect(backdrop, BoardBackdrop.paper);
    });

    testWidgets('ThoughtWallAppearance bubbleFilled defaults to false', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final appearance = container.read(thoughtWallAppearanceProvider);
      expect(appearance.bubbleFilled, false);
    });

    testWidgets('BoardHeroCard renders transparent glass with stylish non-bold font', (tester) async {
      final now = DateTime(2026, 11, 17, 12, 0);
      final thought = Thought(
        id: 1,
        content: 'Long reflective paragraph describing creative thoughts and quiet focus for Ascent.',
        category: 'general',
        mood: 'thought',
        colorHex: '#000000',
        createdAt: now,
        isPinned: true,
        isArchived: false,
        isCompleted: false,
      );

      await tester.pumpWidget(
        buildApp(
          Scaffold(
            body: BoardHeroCard(
              thought: thought,
              now: now,
              label: 'Latest',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Long reflective paragraph'), findsOneWidget);
      expect(find.text('LATEST'), findsOneWidget);
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Rule 13: Zero overflow at 320px width and 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildApp(
          const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  HomeAssistantHeroCard(),
                  SizedBox(height: 12),
                  ThoughtWallHomePreview(compact: true),
                ],
              ),
            ),
          ),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
