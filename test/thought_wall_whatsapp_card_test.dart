import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'support/returning_user_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      ...returningUserGuidePrefs,
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp(Widget child, {double width = 390, double textScale = 1.0, bool isDark = true}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        thoughtDaoProvider.overrideWithValue(db.thoughtDao),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: isDark ? AscentTheme.dark() : AscentTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('Thought Wall WhatsApp Card Redesign & Structure', () {
    testWidgets('renders WhatsApp quoted prompt box, full-width message, and bottom-right status footer', (tester) async {
      final thought = Thought(
        id: 101,
        content: 'This is my personal insight that takes full card width.',
        category: 'learning',
        mood: 'idea',
        promptQuestion: 'What is one thing you learned today?',
        isPinned: true,
        isArchived: false,
        isCompleted: false,
        colorHex: '#6366F1',
        createdAt: DateTime(2026, 10, 22, 14, 30),
      );

      await tester.pumpWidget(
        buildApp(
          ThoughtCardBubble(
            thought: thought,
            index: 0,
            compact: true,
            categoryLabel: 'Learning',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. WhatsApp Quoted reply / prompt box
      expect(find.text('Prompt'), findsOneWidget);
      expect(find.text('What is one thing you learned today?'), findsOneWidget);
      expect(find.byIcon(Icons.reply_rounded), findsOneWidget);

      // 2. Category hashtag
      expect(find.text('#Learning'), findsOneWidget);

      // 3. Message body takes full card width
      expect(
        find.text('This is my personal insight that takes full card width.'),
        findsOneWidget,
      );

      // 4. WhatsApp Footer with pin, timestamp, status ticks, and expand chevron
      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
      expect(find.text('Oct 22 • 2:30 PM'), findsOneWidget);
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(find.byTooltip('Mark done'), findsOneWidget);
      expect(find.byTooltip('Expand thought'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // Verify no edit button in compact mode
      expect(find.byTooltip('Edit thought'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('toggles between active (single tick) and completed (WhatsApp double-tick)', (tester) async {
      final id = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Finish reading system architecture chapters',
        ),
      );

      final thought = (await db.thoughtDao.getThoughtById(id))!;

      await tester.pumpWidget(
        buildApp(
          ThoughtCardBubble(
            thought: thought,
            index: 0,
            compact: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially active -> single tick icon and 'Mark done' tooltip
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(find.byTooltip('Mark done'), findsOneWidget);

      // Tap tick to mark done
      await tester.tap(find.byTooltip('Mark done'));
      await tester.pumpAndSettle();

      // Re-fetch updated thought
      final updated = (await db.thoughtDao.getThoughtById(id))!;
      expect(updated.isCompleted, isTrue);

      await tester.pumpWidget(
        buildApp(
          ThoughtCardBubble(
            thought: updated,
            index: 0,
            compact: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Completed -> WhatsApp double check icon and 'Mark open' tooltip
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      expect(find.byTooltip('Mark open'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('tapping expand opens full action suite and collapse restores compact layout', (tester) async {
      final thought = Thought(
        id: 202,
        content: 'Long reflective thought to expand into detailed actions',
        category: 'general',
        mood: 'thought',
        isPinned: false,
        isArchived: false,
        isCompleted: false,
        colorHex: '#6366F1',
        createdAt: DateTime(2026, 10, 22, 10, 15),
      );

      await tester.pumpWidget(
        buildApp(
          ThoughtCardBubble(
            thought: thought,
            index: 0,
            compact: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Edit thought'), findsNothing);

      // Tap expand dropdown chevron
      await tester.tap(find.byTooltip('Expand thought'));
      await tester.pumpAndSettle();

      // Now expanded -> Edit thought, Copy text, and Collapse are visible
      expect(find.byTooltip('Edit thought'), findsOneWidget);
      expect(find.byTooltip('Copy text'), findsOneWidget);
      expect(find.byTooltip('Collapse thought'), findsOneWidget);

      // Tap collapse
      await tester.tap(find.byTooltip('Collapse thought'));
      await tester.pumpAndSettle();

      // Collapsed back -> Edit button hidden, Expand chevron present
      expect(find.byTooltip('Edit thought'), findsNothing);
      expect(find.byTooltip('Expand thought'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('immune to overflow at 320px width with 2.0x accessibility text scale', (tester) async {
      final thought = Thought(
        id: 303,
        content: 'Stress testing layout with long text in compact bubble with tags and timestamps',
        category: 'architecture_systems',
        mood: 'promise',
        promptQuestion: 'What went exceptionally well in today’s system engineering sprint?',
        isPinned: true,
        isArchived: true,
        isCompleted: true,
        colorHex: '#6366F1',
        createdAt: DateTime(2026, 10, 22, 16, 45),
      );

      await tester.pumpWidget(
        buildApp(
          ThoughtCardBubble(
            thought: thought,
            index: 0,
            compact: true,
            categoryLabel: 'Architecture Systems',
          ),
          width: 320,
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('#Architecture Systems'), findsOneWidget);
      expect(find.text('Promise'), findsOneWidget);
      expect(find.text('ARCHIVED'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
