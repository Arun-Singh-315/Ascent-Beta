import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/learning_hub_card.dart';
import 'package:ascent/features/plans/planning_providers.dart';
import 'package:ascent/features/study_plan/lecture_focus_player_sheet.dart';
import 'package:ascent/features/study_plan/study_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _LargeLearning extends LearningHubNotifier {
  @override
  LearningHubState build() => LearningHubState(
    activeCourseId: 'large',
    activeLectureId: 10001,
    hasStartedLearning: true,
    currentElapsedSeconds: 125,
    courses: [
      Course(
        id: 'large',
        title:
            'A comprehensive course with a deliberately long title for narrow screens',
        modules: [
          CourseModule(
            id: 7,
            title: 'Architecture and systems',
            lectures: List.generate(
              5000,
              (index) => Lecture(
                id: 10000 + index,
                moduleId: 7,
                moduleTitle: 'Architecture and systems',
                title: index == 4999
                    ? 'Final architecture capstone'
                    : 'Lesson $index: Designing a dependable service with a long descriptive title',
                durationSeconds: 1800,
              ),
            ),
          ),
        ],
      ),
    ],
  );
  @override
  void togglePlayPause() => state = state.copyWith(isPlaying: !state.isPlaying);
  @override
  void selectLecture(int lectureId, {bool autoPlay = false}) =>
      state = state.copyWith(activeLectureId: lectureId, isPlaying: autoPlay);
}

TodayActivityItem activity(
  int index, {
  String source = 'custom',
  ActivityKind kind = ActivityKind.todo,
  TodayActivityStatus status = TodayActivityStatus.notStarted,
}) => TodayActivityItem(
  id: 'activity_$index',
  title: 'Activity $index with a longer title to check responsive layout',
  sourceType: source,
  kind: kind,
  status: status,
  elapsedSecondsToday: 125,
  targetMinutes: kind == ActivityKind.duration ? 30 : null,
  learningCourseId: source == 'lecture' ? 'large' : null,
  learningLectureId: source == 'lecture' ? 10001 : null,
  categoryTag: 'Learning',
);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['ASCENT_HUB_SCREENSHOTS'] == '1') {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      for (final weight in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      ]) {
        GoogleFonts.plusJakartaSans(fontWeight: weight);
        GoogleFonts.dmSans(fontWeight: weight);
        GoogleFonts.jetBrainsMono(fontWeight: weight);
      }
      await GoogleFonts.pendingFonts();
    }
  });
  Future<void> capture(WidgetTester tester, String tag) async {
    if (Platform.environment['ASCENT_HUB_SCREENSHOTS'] != '1') return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('hub_qa_capture')),
      );
      final image = await boundary.toImage();
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/ascent_hub_$tag.png',
      ).writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
  }

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  Widget app(
    Widget child, {
    List<TodayActivityItem> activities = const [],
    ThemeData? theme,
    double scale = 1,
  }) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      learningHubProvider.overrideWith(_LargeLearning.new),
      todayActivitiesProvider.overrideWith((ref) => Stream.value(activities)),
      planCollectionsProvider.overrideWith((ref) => Stream.value([])),
    ],
    child: MaterialApp(
      theme: theme ?? AscentTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RepaintBoundary(
        key: const ValueKey('hub_qa_capture'),
        child: Scaffold(body: child),
      ),
    ),
  );

  testWidgets(
    '10,000 activities stay capped on Home and lazy in the full list',
    (tester) async {
      final activities = [for (var i = 0; i < 10000; i++) activity(i)];
      await tester.pumpWidget(
        app(
          const SingleChildScrollView(child: ActivityHubCard()),
          activities: activities,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ActivityRowItem), findsNWidgets(4));
      await tester.ensureVisible(find.text('Show more'));
      await tester.tap(find.text('Show more'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityRowItem), findsNWidgets(20));
      await tester.ensureVisible(find.byKey(const ValueKey('hub_full_list')));
      await tester.tap(find.byKey(const ValueKey('hub_full_list')));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('hub_full_activity_list'));
      expect(list, findsOneWidget);
      expect(
        find
            .descendant(of: list, matching: find.byType(ActivityRowItem))
            .evaluate()
            .length,
        lessThan(30),
      );
      expect(
        tester.widget<ListView>(list).childrenDelegate.estimatedChildCount,
        10000,
      );
      await tester.drag(list, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('hub_full_list_search')),
        'Activity 9999',
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListView>(list).childrenDelegate.estimatedChildCount,
        1,
      );
      expect(
        tester
            .widget<ActivityRowItem>(
              find.descendant(of: list, matching: find.byType(ActivityRowItem)),
            )
            .activity
            .id,
        'activity_9999',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Compact rows mix lectures and timers; running work stays first',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final activities = [
        activity(0),
        activity(1, source: 'lecture'),
        activity(
          2,
          kind: ActivityKind.duration,
          status: TodayActivityStatus.paused,
        ),
        activity(
          3,
          kind: ActivityKind.duration,
          status: TodayActivityStatus.inProgress,
        ),
      ];
      await tester.pumpWidget(
        app(
          const SingleChildScrollView(child: ActivityHubCard()),
          activities: activities,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<ActivityRowItem>(find.byType(ActivityRowItem))
            .first
            .activity
            .id,
        'activity_3',
      );
      await capture(tester, 'things_hub');
      expect(find.byType(ActivityRowItem), findsNWidgets(4));
      expect(
        find.byKey(const ValueKey('activity_hub_type_filters')),
        findsNothing,
      );
      expect(find.text('Start'), findsNWidgets(1));
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final preset in DayThemePreset.values) {
    for (final dark in [false, true]) {
      testWidgets(
        'Learning titles and timer fit 320px at 2x: $preset dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            app(
              const SingleChildScrollView(child: LearningHubCard()),
              theme: dark
                  ? AscentTheme.dark(preset: preset)
                  : AscentTheme.light(preset: preset),
              scale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('2/5000'), findsOneWidget);
          // Home stays glanceable: no "next lecture" line, one-line titles.
          expect(
            find.byKey(const ValueKey('home_learning_next')),
            findsNothing,
          );
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('home_learning_title')))
                .maxLines,
            1,
          );
          await tester.ensureVisible(find.text('Resume'));
          await tester.tap(find.text('Resume'));
          await tester.pump();
          expect(find.text('Pause'), findsOneWidget);
          await capture(tester, 'learning_${preset.name}_$dark');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'A lecture opens its player, whose queue is lazy and searchable',
    (tester) async {
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            child: ActivityRowItem(activity: activity(1, source: 'lecture')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open lecture'));
      await tester.pumpAndSettle();
      expect(find.byType(LectureFocusPlayerSheet), findsOneWidget);
      final outer = find
          .descendant(
            of: find.byType(LectureFocusPlayerSheet),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Lecture queue'),
        350,
        scrollable: outer,
      );
      await tester.tap(find.text('Lecture queue'));
      await tester.pumpAndSettle();
      final queue = find.byKey(const ValueKey('lecture_queue_list'));
      expect(tester.getSize(queue).height, lessThanOrEqualTo(320));
      expect(
        tester.widget<ListView>(queue).childrenDelegate.estimatedChildCount,
        5000,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('lecture_queue_search')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('lecture_queue_search')),
        'Final architecture',
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ListView>(queue).childrenDelegate.estimatedChildCount,
        1,
      );
      expect(find.text('Final architecture capstone'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('A module with 5000 lectures has a bounded lazy list', (
    tester,
  ) async {
    await tester.pumpWidget(app(const StudyPlanScreen()));
    await tester.pumpAndSettle();
    final module = find.byKey(const ValueKey('course_module_7'));
    await tester.ensureVisible(module);
    await tester.tap(
      find
          .descendant(
            of: module,
            matching: find.text('Architecture and systems'),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final list = find.descendant(of: module, matching: find.byType(ListView));
    expect(tester.getSize(list).height, 360);
    expect(find.text('Final architecture capstone'), findsNothing);
    final builtTitles = find
        .descendant(of: module, matching: find.byType(Text))
        .evaluate()
        .where(
          (element) =>
              ((element.widget as Text).data ?? '').startsWith('Lesson '),
        )
        .length;
    expect(builtTitles, lessThan(30));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'Syllabus search reaches the last of 5000 lectures and recovers from no matches',
    (tester) async {
      await tester.pumpWidget(app(const StudyPlanScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Lectures'));
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('lecture_search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'Final architecture');
      await tester.pumpAndSettle();
      expect(find.text('Final architecture capstone'), findsOneWidget);
      await tester.enterText(search, 'Unmatched unique query');
      await tester.pumpAndSettle();
      expect(find.text('No lectures match this view.'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
      expect(find.text('No lectures match this view.'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
