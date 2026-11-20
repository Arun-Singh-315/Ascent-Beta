import 'package:flutter/services.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/today/widgets/things_interactive_card.dart';
import 'package:ascent/shared/widgets/ascent_segmented_control.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayActivityItem makeActivity({
  required String id,
  required String title,
  String? notes,
  ActivityKind kind = ActivityKind.todo,
  TodayActivityStatus status = TodayActivityStatus.notStarted,
  int? targetMinutes,
  String sourceType = 'task',
  String priority = 'normal',
  int? linkedTaskId,
  bool isOverdue = false,
  DateTime? scheduledTime,
}) => TodayActivityItem(
  id: id,
  title: title,
  notes: notes,
  kind: kind,
  status: status,
  sourceType: sourceType,
  categoryTag: 'Task',
  elapsedSecondsToday: 0,
  targetMinutes: targetMinutes,
  priority: priority,
  linkedTaskId: linkedTaskId,
  isOverdue: isOverdue,
  scheduledTime: scheduledTime,
);

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
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  setUpAll(() async {
    if (const bool.fromEnvironment('HOME_SCREENSHOTS')) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  testWidgets(
    'Shared horizontal highlight matches unequal segment widths in both reading directions',
    (tester) async {
      for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
        var selected = 'all';
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(direction),
            theme: AscentTheme.light(),
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 288,
                    child: StatefulBuilder(
                      builder: (context, update) =>
                          AscentSegmentedControl<String>(
                            segments: const [
                              AscentSegment(
                                key: ValueKey('width_all'),
                                value: 'all',
                                label: 'All',
                                flex: 2,
                              ),
                              AscentSegment(
                                key: ValueKey('width_task'),
                                value: 'task',
                                label: 'To-dos',
                                flex: 3,
                              ),
                              AscentSegment(
                                key: ValueKey('width_timer'),
                                value: 'timer',
                                label: 'Timers',
                                flex: 3,
                              ),
                              AscentSegment(
                                key: ValueKey('width_medicine'),
                                value: 'medicine',
                                label: 'Medicines',
                                flex: 4,
                              ),
                            ],
                            selected: selected,
                            onChanged: (value) =>
                                update(() => selected = value),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final value in ['all', 'task', 'timer', 'medicine']) {
          final segment = find.byKey(ValueKey('width_$value'));
          await tester.tap(segment);
          await tester.pumpAndSettle();
          final target = tester.getRect(segment);
          final highlight = tester.getRect(find.byType(AnimatedPositioned));
          expect(highlight.left, closeTo(target.left, .01));
          expect(highlight.width, closeTo(target.width, .01));
          expect(selected, value);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'ThingsInteractiveCard renders single ground border enclosure with no nested cards',
    (tester) async {
      final activity = makeActivity(
        id: 'act_ground_1',
        title: 'Review production pull request',
        linkedTaskId: 10,
        priority: 'high',
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ThingsInteractiveCard(activity: activity),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ground ActivityRowItem is rendered with ground style (no inner border/card)
      final rowFinder = find.byType(ActivityRowItem);
      expect(rowFinder, findsOneWidget);
      final rowWidget = tester.widget<ActivityRowItem>(rowFinder);
      expect(rowWidget.ground, isTrue);

      // Verify title is rendered prominently
      expect(find.text('Review production pull request'), findsOneWidget);

      // Verify Blueprint button exists
      expect(find.text('Blueprint'), findsOneWidget);

      // Tap Blueprint button to expand story micro-steps inline
      await tester.tap(find.text('Blueprint'));
      await tester.pumpAndSettle();

      expect(find.text('Hide'), findsOneWidget);
      expect(find.textContaining('Story Micro-Steps'), findsOneWidget);
    },
  );
}
