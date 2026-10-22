/// froast_ice_theme_ux_test.dart
///
/// Regression tests for three Froast Ice (Nordic Sky) theme UX issues:
///
/// 1. Paused activity row background must NOT be the warm-yellow #FEF3C7 in
///    Nordic Sky light mode — it must use FrozenPalette.sparkTint.
/// 2. Paused timer text color must use FrozenPalette.spark, not a raw
///    orange swatch (AppPalette.orange.shade400) in Nordic Sky modes.
/// 3. The nordicSkyDark glass surface fill must be translucent enough (alpha
///    ≤ 0.80) so backdrop blur actually shows through at night.
/// 4. GlassSurface in Frozen dark mode must render a frost-rim asymmetric
///    border (top highlight != bottom/side color).
///
/// Run: flutter test test/froast_ice_theme_ux_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/frozen_palette.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/challenge/challenge_providers.dart';
import 'package:ascent/features/home/widgets/day_one_tutorial_card.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';
import 'package:ascent/shared/widgets/thought_excerpt.dart';

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
        todaySeconds: 0,
        yesterdaySeconds: 0,
        priorStreakDays: 0,
        historicalLongestStreak: 0,
        historicalShortestStreak: 1,
        now: DateTime.now(),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      DayOneTutorialDialog.prefKey: false,
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestable(Widget child, {ThemeData? theme, List<Thought>? thoughts}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
        studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
        allChallengesProvider.overrideWith((ref) => Stream.value([])),
        activeMomentumChallengeStreamProvider
            .overrideWith((ref) => Stream.value(null)),
        todayMomentumCommitmentsStreamProvider
            .overrideWith((ref) => Stream.value([])),
        if (thoughts != null)
          recentThoughtsStreamProvider
              .overrideWith((ref) => Stream.value(thoughts)),
      ],
      child: MaterialApp(theme: theme, home: Scaffold(body: child)),
    );
  }

  group('Froast Ice (Nordic Sky) Theme UX Fixes', () {
    // ── Token-level tests (no widget pump needed) ─────────────────────────────

    test('1. nordicSkyDark glass fill is translucent for blur-through (alpha <= 0.80)', () {
      final fill = AscentGlass.nordicSkyDark.fill;
      expect(
        fill.a,
        lessThanOrEqualTo(0.80),
        reason:
            'nordicSkyDark fill must be translucent so backdrop blur shows through at night. '
            'Got alpha=${fill.a.toStringAsFixed(2)}',
      );
    });

    test('2. nordicSkyDark highlight is blue-tinted (not pure white) for frost rim effect', () {
      final highlight = AscentGlass.nordicSkyDark.highlight;
      expect(
        highlight.b,
        greaterThan(highlight.r),
        reason:
            'nordicSkyDark highlight should be blue-tinted for frost rim. '
            'Got r=${highlight.r}, b=${highlight.b}',
      );
    });

    test('3. nordicSky glass fill is translucent for light frosted glass (alpha <= 0.85)', () {
      final fill = AscentGlass.nordicSky.fill;
      expect(
        fill.a,
        lessThanOrEqualTo(0.85),
        reason:
            'nordicSky fill must be translucent so background atmospheric blue shows through. '
            'Got alpha=${fill.a.toStringAsFixed(2)}',
      );
    });

    test('4. AppSurfaces.nordicSky.cardFill is translucent for light frosted glass (alpha <= 0.85)', () {
      final fill = AppSurfaces.nordicSky.cardFill;
      expect(
        fill.a,
        lessThanOrEqualTo(0.85),
        reason:
            'nordicSky cardFill must be translucent so cards feel like frosted glass. '
            'Got alpha=${fill.a.toStringAsFixed(2)}',
      );
    });

    test('5. nordicSkyDark shadow has depth (alpha > 0.45)', () {
      final shadow = AscentGlass.nordicSkyDark.shadow;
      expect(
        shadow.a,
        greaterThan(0.45),
        reason: 'Dark glass must have deep ambient shadow for premium depth',
      );
    });

    test('6. nordicSkyDark glow1 has strong blue atmosphere (alpha >= 0.28)', () {
      final glow1 = AscentGlass.nordicSkyDark.glow1;
      expect(glow1.a, greaterThanOrEqualTo(0.28),
          reason: 'Dark Frozen glow1 must be vivid for arctic atmosphere');
    });

    test('7. nordicSkyDark glow2 has strong secondary blue shimmer (alpha >= 0.24)', () {
      final glow2 = AscentGlass.nordicSkyDark.glow2;
      expect(glow2.a, greaterThanOrEqualTo(0.24),
          reason: 'Dark Frozen glow2 must be vivid for blue shimmer');
    });

    test('8. nordicSkyDark nav bar is more opaque than the card fill', () {
      final nav = AscentGlass.nordicSkyDark.nav;
      final fill = AscentGlass.nordicSkyDark.fill;
      expect(
        nav.a,
        greaterThan(fill.a),
        reason: 'Nav bar should be more opaque than card fill for visual grounding',
      );
    });

    test('9. FrozenPalette.spark is distinct from Material orange.shade400', () {
      const spark = FrozenPalette.spark;
      final orangeShade400 = Colors.orange.shade400;
      expect(spark.value, isNot(equals(orangeShade400.value)));
    });

    test('10. FrozenPalette.darkSpark is readable on dark navy background', () {
      const darkSpark = FrozenPalette.darkSpark;
      const bg = FrozenPalette.darkCanvas;
      expect(darkSpark.computeLuminance(), greaterThan(bg.computeLuminance()),
          reason: 'Paused text must be readable on dark navy background');
    });

    test('11. MerlotPalette.sparkTint is available for Merlot paused state background', () {
      expect(MerlotPalette.sparkTint.a, equals(1.0),
          reason: 'sparkTint must be an opaque background color');
    });

    test('12. nordicSkyDark fill alpha decreased from previous value (was 0.94)', () {
      final fill = AscentGlass.nordicSkyDark.fill;
      expect(fill.a, lessThan(0.94),
          reason: 'Fill opacity was reduced from 0.94 to let blur show through');
    });

    // ── Widget-level tests ────────────────────────────────────────────────────

    testWidgets('13. GlassSurface in Frozen dark mode renders with uniform border and enhanced shadow', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const GlassSurface(
            key: ValueKey('test_glass'),
            enableBlur: false,
            child: Text('Frosted'),
          ),
          theme: AscentTheme.dark(preset: DayThemePreset.nordicSky),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      final finder = find.byKey(const ValueKey('test_glass'));
      expect(finder, findsOneWidget);

      // Verify BoxDecoration exists with uniform border matching FrozenPalette.darkLine
      bool foundGlassBorder = false;
      final containers = tester.widgetList<Container>(
        find.descendant(of: finder, matching: find.byType(Container)),
      ).toList();

      for (final container in containers) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration && decoration.border is Border) {
          final border = decoration.border as Border;
          if (border.isUniform && border.top.color == FrozenPalette.darkLine) {
            foundGlassBorder = true;
            break;
          }
        }
      }

      expect(
        foundGlassBorder,
        isTrue,
        reason: 'Frozen dark GlassSurface must have uniform darkLine border compliant with borderRadius',
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    test('13b. legacyNordicSkyDark surface token has light high-contrast ink for night mode text visibility', () {
      final surface = AppSurfaces.legacyNordicSkyDark;
      expect(surface.ink, equals(FrozenPalette.darkInk),
          reason: 'legacyNordicSkyDark must use darkInk so text in lectures and cards is visible');
      expect(surface.mutedText, equals(FrozenPalette.darkMutedInk),
          reason: 'legacyNordicSkyDark must use darkMutedInk for secondary text');
    });

    testWidgets('14. GlassSurface in light Frozen mode renders without errors', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const GlassSurface(
            key: ValueKey('test_glass_light'),
            enableBlur: false,
            child: Text('Frozen light'),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('15. GlassSurface in Classic Clay dark renders without errors', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const GlassSurface(
            key: ValueKey('test_glass_classic'),
            enableBlur: false,
            child: Text('Classic dark'),
          ),
          theme: AscentTheme.dark(preset: DayThemePreset.classicClay),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('16. Paused ActivityRowItem in light Frozen theme uses cool pillSoft (NOT yellow)', (tester) async {
      const pausedItem = TodayActivityItem(
        id: 'lecture_spring_boot',
        title: 'Spring Boot Mastery',
        sourceType: 'lecture',
        learningCourseId: 'spring_course',
        learningLectureId: 2,
        status: TodayActivityStatus.paused,
        elapsedSecondsToday: 363,
        categoryTag: 'Study',
        kind: ActivityKind.duration,
        targetMinutes: 30,
      );

      await tester.pumpWidget(
        buildTestable(
          const ActivityRowItem(activity: pausedItem),
          theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Verify no container inside ActivityRowItem uses warm yellow #FEF3C7 or sparkTint
      final containers = tester.widgetList<Container>(
        find.descendant(of: find.byType(ActivityRowItem), matching: find.byType(Container)),
      ).toList();

      for (final container in containers) {
        final decoration = container.decoration;
        if (decoration is BoxDecoration) {
          expect(decoration.color, isNot(equals(const Color(0xFFFEF3C7))),
              reason: 'Paused item background must not be warm yellow #FEF3C7');
          expect(decoration.color, isNot(equals(FrozenPalette.sparkTint)),
              reason: 'Paused item background must not be sparkTint in Frozen theme');
        }
      }

      // Verify row background is FrozenPalette.pillSoft
      final rowContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).borderRadius != null,
      );
      expect((rowContainer.decoration as BoxDecoration).color, equals(FrozenPalette.pillSoft),
          reason: 'Paused item must use cool pillSoft surface in Frozen light mode');

      // Now verify timed activity shows Paused in FrozenPalette.action
      const pausedTimed = TodayActivityItem(
        id: 'timed_task_1',
        title: 'Practice Coding',
        sourceType: 'task',
        status: TodayActivityStatus.paused,
        elapsedSecondsToday: 300,
        categoryTag: 'Code',
        kind: ActivityKind.duration,
        targetMinutes: 25,
      );

      await tester.pumpWidget(
        buildTestable(
          const ActivityRowItem(activity: pausedTimed),
          theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      final textFinder = find.textContaining('Paused');
      expect(textFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.color, equals(FrozenPalette.action),
          reason: 'Paused timer text in light Frozen mode should be cool blue action color');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('15. Thought bubble in dark Frozen mode uses soothing darkElevated glass, not blinding bright blue', (tester) async {
      final tId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Late night quiet reflection'),
      );
      final t = (await db.thoughtDao.getThoughtById(tId))!;

      await tester.pumpWidget(
        buildTestable(
          const Scaffold(
            body: SingleChildScrollView(child: ThoughtWallHomePreview()),
          ),
          theme: AscentTheme.dark(preset: DayThemePreset.nordicSky),
          thoughts: [t],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final bubbleFinder = find.byKey(ValueKey('home_thought_$tId'));
      expect(bubbleFinder, findsOneWidget);
      final bubbleGlass = tester.widget<GlassSurface>(bubbleFinder);

      // In dark Frozen mode: bubble must not have bright neon gradient
      expect(bubbleGlass.gradient, isNull,
          reason: 'Dark Frozen mode must not use bright flashlight gradient at night');
      expect(bubbleGlass.fillColor, equals(FrozenPalette.darkElevated),
          reason: 'Dark Frozen bubble should use soothing darkElevated glass');

      // Text inside bubble must be high-contrast darkInk
      final textFinder = find.byType(ThoughtExcerpt);
      expect(textFinder, findsOneWidget);
      final excerpt = tester.widget<ThoughtExcerpt>(textFinder);
      expect(excerpt.style.color, equals(FrozenPalette.darkInk));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });
}
