import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/features/thought_wall/thought_wall_preferences.dart';
import 'package:ascent/features/thought_wall/thought_wall_appearance_sheet.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:drift/native.dart';
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

  Widget buildApp(Widget child, {double width = 390, double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        thoughtDaoProvider.overrideWithValue(db.thoughtDao),
        sharedPreferencesProvider.overrideWithValue(prefs),
        userProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('Display Mode UI in Settings', () {
    testWidgets('all three squares are prominently sized and do not stick to names', (tester) async {
      await tester.pumpWidget(buildApp(const SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Display Mode'), findsOneWidget);
      expect(find.text('Day / Light'), findsOneWidget);
      expect(find.text('Night / Dark'), findsOneWidget);
      expect(find.text('System Auto'), findsAtLeastNWidgets(1));

      // Verify each option is housed in a prominent card with circular icon badge
      final dayFinder = find.ancestor(of: find.text('Day / Light'), matching: find.byType(InkWell)).first;
      final dayBox = tester.getRect(dayFinder);
      expect(dayBox.height, greaterThanOrEqualTo(65));
      expect(dayBox.width, greaterThanOrEqualTo(70));
    });

    testWidgets('immune to overflow at 320px width with 2.0x accessibility text scale', (tester) async {
      await tester.pumpWidget(buildApp(const SettingsScreen(), width: 320, textScale: 2.0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.text('Display Mode'), findsOneWidget);
      expect(find.text('Day / Light'), findsOneWidget);
      expect(find.text('Night / Dark'), findsOneWidget);
      expect(find.text('System Auto'), findsAtLeastNWidgets(1));
    });
  });

  group('Thought Cards Tone and Apply to Home in Settings', () {
    testWidgets('allows tone selection and Apply to Home toggle', (tester) async {
      await tester.pumpWidget(buildApp(const SettingsScreen()));
      await tester.pumpAndSettle();

      // Scroll to Thought Cards section
      await tester.scrollUntilVisible(find.text('Thought Cards'), 200);
      expect(find.text('Thought Cards'), findsOneWidget);
      expect(find.text('Apply to Home'), findsOneWidget);
      expect(find.text('Match Home cards with selected tone'), findsOneWidget);

      // Tap Sage tone
      await tester.tap(find.text('Sage'));
      await tester.pumpAndSettle();

      // Tap Apply to Home switch
      await tester.tap(find.text('Apply to Home'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
      final appearance = container.read(thoughtWallAppearanceProvider);
      expect(appearance.tone, ThoughtCardTone.sage);
      expect(appearance.applyToHome, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('ThoughtWallAppearanceSheet offers Apply to Home switch', (tester) async {
      await tester.pumpWidget(buildApp(const Scaffold(body: ThoughtWallAppearanceSheet())));
      await tester.pumpAndSettle();

      expect(find.text('Wall appearance'), findsOneWidget);
      expect(find.text('Apply to Home'), findsOneWidget);
      expect(find.text('Match Home cards with selected tone'), findsOneWidget);

      await tester.tap(find.text('Apply to Home'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(ThoughtWallAppearanceSheet)));
      final appearance = container.read(thoughtWallAppearanceProvider);
      expect(appearance.applyToHome, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  group('Thought Wall Toggle and Selection Delete Option Outside', () {
    testWidgets('segmented 3-way toggle renders All, Today, History with responsive feedback', (tester) async {
      await tester.pumpWidget(buildApp(const ThoughtWallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text("TODAY'S REFLECTIONS"), findsOneWidget);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('OLDER REFLECTIONS'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('provides prominent Delete option outside when selecting thoughts', (tester) async {
      // Seed a thought
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Note to be deleted outside'),
      );

      await tester.pumpWidget(buildApp(const ThoughtWallScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Note to be deleted outside'), findsOneWidget);

      // Long press the card to enter selection mode
      await tester.longPress(find.text('Note to be deleted outside'));
      await tester.pumpAndSettle();

      // Selection actions bar is now displayed at bottom
      expect(find.byKey(const ValueKey('thought_selection_actions')), findsOneWidget);
      // Verify Delete button is directly present outside on the bar
      expect(find.widgetWithText(TextButton, 'Delete'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Category'), findsOneWidget);

      // Tap Delete outside
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      // Verify undo snackbar is shown
      expect(find.text('Thought removed'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Verify thought is removed from active list
      expect(find.text('Note to be deleted outside'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Home Thought Preview Custom Tone and Font Typography', () {
    testWidgets('Home thoughts render with AppTypography.thoughtContent and reflect custom tone when applyToHome is true', (tester) async {
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Reflective thought on Home'),
      );

      // Set appearance with custom tone and applyToHome = true
      await prefs.setString(
        thoughtWallAppearanceKey,
        '{"version":1,"style":"soft","tone":"sage","density":"compact","applyToHome":true}',
      );

      await tester.pumpWidget(buildApp(const Scaffold(body: ThoughtWallHomePreview())));
      await tester.pumpAndSettle();

      expect(find.text('Reflective thought on Home'), findsOneWidget);

      // Verify the thought text uses comfortable 14.5px font with 1.5 height
      final textWidget = tester.widget<Text>(find.text('Reflective thought on Home'));
      final spanStyle = textWidget.textSpan?.style ?? textWidget.style;
      expect(spanStyle?.fontSize, 14.5);
      expect(spanStyle?.height, 1.5);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
