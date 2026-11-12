import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/activity_timer_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _Tracker extends TimeTrackingNotifier {
  static TimeTrackingState initial = const TimeTrackingState();
  int? resumedTask;
  @override
  TimeTrackingState build() => initial;
  void tick(int seconds) => state = state.copyWith(elapsedSeconds: seconds);
  @override
  Future<void> switchToTask({
    required String title,
    int? taskId,
    String sourceType = 'task',
    int? categoryId,
    bool autoStart = true,
  }) async {
    resumedTask = taskId;
  }
}

class _Learning extends LearningHubNotifier {
  @override
  LearningHubState build() => LearningHubState(
    activeCourseId: 'other',
    activeLectureId: 1,
    currentElapsedSeconds: 900,
    courses: [
      for (final id in ['mine', 'other'])
        Course(
          id: id,
          title: id,
          modules: [
            const CourseModule(
              id: 1,
              title: 'Module',
              lectures: [
                Lecture(
                  id: 1,
                  moduleId: 1,
                  moduleTitle: 'Module',
                  title: 'Lesson',
                  durationSeconds: 1200,
                  elapsedSeconds: 120,
                ),
              ],
            ),
          ],
        ),
    ],
  );
}

TimeSession session({int id = 10, int? task = 1}) => TimeSession(
  id: id,
  label: 'Focus',
  activityType: 'study',
  categoryId: 1,
  linkedTaskId: task,
  startedAt: DateTime(2026),
  pausedIntervals: '[]',
  status: 'running',
  durationSeconds: 0,
  activityRefType: 'task',
  createdAt: DateTime(2026),
);
TodayActivityItem item({
  String id = 'timer',
  int? task = 1,
  int? sessionId,
  int elapsed = 600,
  int? goal = 25,
  TodayActivityStatus status = TodayActivityStatus.inProgress,
}) => TodayActivityItem(
  id: id,
  title: 'Build a thoughtful timer experience',
  sourceType: 'task',
  status: status,
  elapsedSecondsToday: elapsed,
  linkedTaskId: task,
  linkedSessionId: sessionId,
  categoryTag: 'Task',
  kind: ActivityKind.duration,
  targetMinutes: goal,
);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late ProviderContainer container;
  setUp(() {
    _Tracker.initial = const TimeTrackingState();
    container = ProviderContainer(
      overrides: [
        timeTrackingProvider.overrideWith(_Tracker.new),
        learningHubProvider.overrideWith(_Learning.new),
      ],
    );
  });
  tearDown(() => container.dispose());
  Widget app(Widget child, {bool dark = false, double scale = 1}) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ),
        ),
      );

  testWidgets('Live ticks preserve earlier sessions in the daily total', (
    tester,
  ) async {
    _Tracker.initial = TimeTrackingState(
      activeSession: session(),
      elapsedSeconds: 120,
      isRunning: true,
    );
    await tester.pumpWidget(app(ActivityTimerProgress(activity: item())));
    expect(find.text('10:00 / 25:00'), findsOneWidget);
    (container.read(timeTrackingProvider.notifier) as _Tracker).tick(150);
    await tester.pumpAndSettle();
    expect(find.text('10:30 / 25:00'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(.42, .001),
    );
  });

  testWidgets('Standalone sessions cannot borrow another unlinked timer', (
    tester,
  ) async {
    _Tracker.initial = TimeTrackingState(
      activeSession: session(id: 99, task: null),
      elapsedSeconds: 120,
      isRunning: true,
    );
    await tester.pumpWidget(
      app(ActivityTimerProgress(activity: item(task: null, sessionId: 10))),
    );
    (container.read(timeTrackingProvider.notifier) as _Tracker).tick(500);
    await tester.pump();
    expect(find.text('10:00 / 25:00'), findsOneWidget);
  });

  testWidgets(
    'Overtime caps the track while count-up timers have no fake goal',
    (tester) async {
      await tester.pumpWidget(
        app(
          Column(
            children: [
              ActivityTimerProgress(
                activity: item(
                  elapsed: 1600,
                  status: TodayActivityStatus.paused,
                ),
              ),
              ActivityTimerProgress(
                activity: item(
                  id: 'open',
                  goal: null,
                  status: TodayActivityStatus.paused,
                ),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Paused · Goal reached · +01:40'), findsOneWidget);
      expect(find.text('Paused · Count up'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
    },
  );

  testWidgets('Lecture progress stays scoped to its course', (tester) async {
    const lecture = TodayActivityItem(
      id: 'lecture',
      title: 'Lesson',
      sourceType: 'lecture',
      status: TodayActivityStatus.paused,
      elapsedSecondsToday: 0,
      learningCourseId: 'mine',
      learningLectureId: 1,
      categoryTag: 'Study',
      kind: ActivityKind.duration,
    );
    await tester.pumpWidget(
      app(const ActivityTimerProgress(activity: lecture)),
    );
    expect(find.text('02:00 / 20:00'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Timer controls fit 320px at 2x and Resume selects its own task dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            ActivityRowItem(
              activity: item(task: 7, status: TodayActivityStatus.paused),
              compact: true,
              ground: true,
            ),
            dark: dark,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('10:00 / 25:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Resume'));
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();
        expect(
          (container.read(timeTrackingProvider.notifier) as _Tracker)
              .resumedTask,
          7,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
