import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/app/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mind Palace Privacy and Bubble Customization Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets('Locked private promise displays privacy shield on Home Thought preview', (tester) async {
      final now = DateTime.now();
      final privateThought = Thought(
        id: 99,
        content: 'Secret personal commitment',
        promptQuestion: 'secret personal commitment',
        mood: 'promise',
        category: 'personal',
        colorHex: '#2D2D3A',
        isPinned: false,
        isCompleted: false,
        isArchived: false,
        createdAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([privateThought])),
            privatePromiseIdsProvider.overrideWith((ref) => {99}),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Content should NOT be visible
      expect(find.text('Secret personal commitment'), findsNothing);
      // Privacy lock shield should be displayed
      expect(find.text('Private commitment · Tap to unlock'), findsOneWidget);
      expect(find.text('PRIVATE PROMISE'), findsOneWidget);
    });

    testWidgets('Unlocked private promise reveals content and deduplicates prompt case-insensitively', (tester) async {
      final now = DateTime.now();
      final thought = Thought(
        id: 99,
        content: 'Kissi se baat ni krni dec tk group mein gayab and work . ❤️',
        promptQuestion: 'kissi se baat ni krni dec tk group mein gayab and work . ❤️',
        mood: 'promise',
        category: 'personal',
        colorHex: '#2D2D3A',
        isPinned: false,
        isCompleted: false,
        isArchived: false,
        createdAt: now,
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([thought])),
          privatePromiseIdsProvider.overrideWith((ref) => {99}),
        ],
      );

      // Unlock it
      container.read(unlockedPromiseIdsProvider.notifier).unlock(99);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show the unlocked badge
      expect(find.text('UNLOCKED PROMISE'), findsOneWidget);
      // Standalone prompt Text widget should be deduplicated (not shown)
      final standalonePrompt = find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data?.toLowerCase().contains('kissi se baat') ?? false),
      );
      expect(standalonePrompt, findsNothing);
    });

    testWidgets('Mind Palace card style button opens style sheet and customizes fill and border', (tester) async {
      final now = DateTime.now();
      final thought = Thought(
        id: 1,
        content: 'i can & i will 🔥',
        promptQuestion: null,
        mood: 'thought',
        category: 'general',
        colorHex: '#2D2D3A',
        isPinned: false,
        isCompleted: false,
        isArchived: false,
        createdAt: now,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([thought])),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find style customize button
      final styleBtn = find.byKey(const ValueKey('home_mind_palace_style_btn'));
      expect(styleBtn, findsOneWidget);

      await tester.tap(styleBtn);
      await tester.pumpAndSettle();

      // Style bottom sheet should appear
      expect(find.text('Mind Palace Card Style'), findsOneWidget);
      expect(find.text('Coloured Fill'), findsOneWidget);
      expect(find.text('Border Only'), findsOneWidget);
      expect(find.text('Thin (1px)'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Bold (2.6px)'), findsOneWidget);

      // Tap Border Only
      await tester.tap(find.text('Border Only'));
      await tester.pumpAndSettle();
      expect(prefs.getBool('home_thought_bubble_filled'), isFalse);

      // Tap Bold (2.6px)
      await tester.tap(find.text('Bold (2.6px)'));
      await tester.pumpAndSettle();
      expect(prefs.getDouble('home_thought_bubble_border_width'), 2.6);
    });

    testWidgets('Rule 13: 320px width and 2.0x accessibility text scale immunity', (tester) async {
      final now = DateTime.now();
      final thought = Thought(
        id: 99,
        content: 'A long philosophical reflection on life, priorities, focus and progress.',
        promptQuestion: 'What is truly essential for peace of mind today?',
        mood: 'promise',
        category: 'personal',
        colorHex: '#2D2D3A',
        isPinned: false,
        isCompleted: false,
        isArchived: false,
        createdAt: now,
      );

      tester.view.physicalSize = const Size(320 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([thought])),
            privatePromiseIdsProvider.overrideWith((ref) => {99}),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 700),
                textScaler: TextScaler.linear(2.0),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: ThoughtWallHomePreview(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Expect no overflow exceptions
      expect(tester.takeException(), isNull);
    });
  });
}
