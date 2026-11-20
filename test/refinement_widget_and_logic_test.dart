import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/shared/widgets/app_chip.dart';
import 'package:ascent/shared/widgets/capped_chip_wrap.dart';
import 'package:ascent/shared/widgets/thought_excerpt.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'weather_city': 'Bengaluru, India',
      'ascent_theme_mode': 'dark',
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ThoughtExpandedRegistry.clear();
  });

  tearDown(() async {
    await db.close();
    ThoughtExpandedRegistry.clear();
  });

  group('Phase 3: Overflow Detection & ID-based Expansion Tests', () {
    testWidgets('Short text does not show "Show more" toggle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.dark(),
          home: const Scaffold(
            body: SizedBox(
              width: 350,
              child: ThoughtExcerpt(
                content: 'Short thought on one line.',
                style: TextStyle(fontSize: 14),
                maxLines: 4,
                thoughtId: 101,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Short thought on one line.'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets(
      'Long overflowing text shows "Show more" toggle and expands inline',
      (tester) async {
        const longText =
            'Line 1: Building a serene architecture.\n'
            'Line 2: Every line flows naturally.\n'
            'Line 3: Zero popup dialogs on expansion.\n'
            'Line 4: Apple-style restraint and clarity.\n'
            'Line 5: Deep soothing tones for mindspace.\n'
            'Line 6: Generous readability preserved.';

        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: const Scaffold(
              body: SizedBox(
                width: 350,
                child: ThoughtExcerpt(
                  content: longText,
                  style: TextStyle(fontSize: 14),
                  maxLines: 3,
                  thoughtId: 202,
                  toggleKey: ValueKey('test_toggle_202'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('test_toggle_202')), findsOneWidget);
        expect(find.text('Show more'), findsOneWidget);
        expect(ThoughtExpandedRegistry.isExpanded(202), isFalse);

        // Tap toggle to expand
        await tester.tap(find.byKey(const ValueKey('test_toggle_202')));
        await tester.pumpAndSettle();

        expect(find.text('Show less'), findsOneWidget);
        expect(ThoughtExpandedRegistry.isExpanded(202), isTrue);

        // Tap again to collapse
        await tester.tap(find.byKey(const ValueKey('test_toggle_202')));
        await tester.pumpAndSettle();

        expect(find.text('Show more'), findsOneWidget);
        expect(ThoughtExpandedRegistry.isExpanded(202), isFalse);
      },
    );

    testWidgets(
      'ID-based expansion state isolates cards so expanding one never expands another',
      (tester) async {
        const textA =
            'A long thought for card A exceeding the threshold.\nLine 2\nLine 3\nLine 4\nLine 5';
        const textB =
            'A long thought for card B exceeding the threshold.\nLine 2\nLine 3\nLine 4\nLine 5';

        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: Scaffold(
              body: Column(
                children: const [
                  SizedBox(
                    width: 350,
                    child: ThoughtExcerpt(
                      content: textA,
                      style: TextStyle(fontSize: 14),
                      maxLines: 2,
                      thoughtId: 301,
                      toggleKey: ValueKey('toggle_301'),
                    ),
                  ),
                  SizedBox(
                    width: 350,
                    child: ThoughtExcerpt(
                      content: textB,
                      style: TextStyle(fontSize: 14),
                      maxLines: 2,
                      thoughtId: 302,
                      toggleKey: ValueKey('toggle_302'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially both are collapsed
        expect(ThoughtExpandedRegistry.isExpanded(301), isFalse);
        expect(ThoughtExpandedRegistry.isExpanded(302), isFalse);

        // Expand card 301 only
        await tester.tap(find.byKey(const ValueKey('toggle_301')));
        await tester.pumpAndSettle();

        expect(ThoughtExpandedRegistry.isExpanded(301), isTrue);
        expect(
          ThoughtExpandedRegistry.isExpanded(302),
          isFalse,
        ); // Card 302 is NOT expanded!
      },
    );
  });

  group('Phase 4: CappedChipWrap & Swipe Delete Tests', () {
    testWidgets(
      'CappedChipWrap caps at 2 rows and shows "+N more" chip, expanding inline on tap',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: Scaffold(
              body: SizedBox(
                width: 300, // Narrow container forcing wrap beyond 2 rows
                child: CappedChipWrap(
                  maxRows: 2,
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    AppChip(label: 'Alpha Chip One'),
                    AppChip(label: 'Beta Chip Two'),
                    AppChip(label: 'Gamma Chip Three'),
                    AppChip(label: 'Delta Chip Four'),
                    AppChip(label: 'Epsilon Chip Five'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show "+N more" chip
        final moreFinder = find.textContaining('more');
        expect(moreFinder, findsOneWidget);

        // Tap "+N more" to expand
        await tester.tap(moreFinder);
        await tester.pumpAndSettle();

        // All 5 chips and "Show less" are visible
        expect(find.text('Alpha Chip One'), findsOneWidget);
        expect(find.text('Epsilon Chip Five'), findsOneWidget);
        expect(find.text('Show less'), findsOneWidget);

        // Tap "Show less" to collapse back
        await tester.tap(find.text('Show less'));
        await tester.pumpAndSettle();

        expect(find.textContaining('more'), findsOneWidget);
      },
    );

    testWidgets(
      'Swipe to delete on Home immediately deletes without confirmation dialog and shows Undo snackbar',
      (tester) async {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Swipe delete without dialog test',
            createdAt: drift.Value(DateTime.now()),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(body: ThoughtWallHomePreview(compact: true)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('home_latest_thought_bubble')),
          findsOneWidget,
        );

        // Swipe to delete
        await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
        await tester.pumpAndSettle();

        // No confirmation dialog was shown!
        expect(find.text('Delete this thought?'), findsNothing);

        // Thought deleted from DB
        final deleted = await db.thoughtDao.getThoughtById(id);
        expect(deleted, isNull);

        // Undo snackbar shown
        expect(find.text('Undo'), findsOneWidget);

        // Tap Undo to restore
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        final restored = await db.thoughtDao.getThoughtById(id);
        expect(restored, isNotNull);
        expect(restored!.content, 'Swipe delete without dialog test');
        expect(
          ThoughtExpandedRegistry.isExpanded(id),
          isFalse,
        ); // Clean expansion state

        ScaffoldMessenger.of(
          tester.element(find.byType(Scaffold)),
        ).hideCurrentSnackBar();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });

  group('Phase 5: 320px Width & 2.0x Text Scale Immunity', () {
  });
}
