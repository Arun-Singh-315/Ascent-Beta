import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/notifications/things_check_in.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/today/things_hub_screen.dart';
import 'package:ascent/features/today/widgets/things_hero_card.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:ascent/shared/widgets/glass_chip.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayActivityItem makeActivity({
  required String id,
  required String title,
  ActivityKind kind = ActivityKind.todo,
  TodayActivityStatus status = TodayActivityStatus.notStarted,
  int? targetMinutes,
  String sourceType = 'task',
  String priority = 'normal',
  int? linkedTaskId,
}) =>
    TodayActivityItem(
      id: id,
      title: title,
      kind: kind,
      status: status,
      sourceType: sourceType,
      categoryTag: 'Task',
      elapsedSecondsToday: 0,
      targetMinutes: targetMinutes,
      priority: priority,
      linkedTaskId: linkedTaskId,
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

  group('Phase 1 & 3: Deep Link & Notifications Contract', () {
    test('routes /things and /history preserving focus and wrapup parameters', () {
      expect(
        NotificationService.destinationForPayload('/things?focus=101&mode=wrapup'),
        '/things?focus=101&mode=wrapup',
      );
      expect(
        NotificationService.destinationForPayload('/history?module=hydration'),
        '/history?module=hydration',
      );
      expect(
        NotificationService.destinationForPayload('ascent://open/things?focus=101'),
        '/things?focus=101',
      );
      expect(
        NotificationService.destinationForPayload('ascent://things'),
        '/things',
      );
    });

    test('ThingsCheckIn carries task id, payload and actions', () async {
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Ship Beta release',
          priority: const drift.Value('high'),
        ),
      );

      final plan = ThingsCheckIn.plan(
        now: DateTime(2026, 11, 2, 9),
        tasks: await db.select(db.taskTable).get(),
        reminders: await db.select(db.reminderTable).get(),
        horizonDays: 7,
      );

      expect(plan.length, 14);
      final firstMidday = plan.firstWhere((p) => p.type == ThingsNotificationType.middayCheckIn);
      expect(firstMidday.taskId, taskId);
      expect(firstMidday.payload, '/things?focus=$taskId');
      expect(firstMidday.actions, containsAll(['things_start', 'things_done', 'things_snooze']));

      final firstWrapup = plan.firstWhere((p) => p.type == ThingsNotificationType.eveningWrapUp);
      expect(firstWrapup.taskId, taskId);
      expect(firstWrapup.payload, '/things?focus=$taskId&mode=wrapup');
      expect(firstWrapup.actions, containsAll(['things_carry', 'things_review']));
    });
  });

  group('Phase 2: Things Hub Hero & Day Progress Line', () {
    testWidgets('ThingsHeroCard displays context badge, title, and action', (tester) async {
      final heroItem = makeActivity(
        id: 'task_hero_1',
        title: 'Review System Architecture',
        kind: ActivityKind.duration,
        targetMinutes: 25,
        priority: 'high',
        linkedTaskId: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ThingsHeroCard(activity: heroItem),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('HIGH PRIORITY'), findsOneWidget);
      expect(find.text('Review System Architecture'), findsOneWidget);
      expect(find.text('25 min'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('ActivityHubCard displays day progress when tasks are done and hides at zero', (
      tester,
    ) async {
      final doneItem = makeActivity(
        id: 'done_1',
        title: 'Morning workout',
        status: TodayActivityStatus.done,
      );
      final pendingItem = makeActivity(
        id: 'pending_1',
        title: 'Submit pull request',
        status: TodayActivityStatus.notStarted,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          todayActivitiesProvider.overrideWith(
            (ref) => Stream.value([doneItem, pendingItem]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: ActivityHubCard(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Progress line should display "1 of 2 done"
      expect(find.text('1 of 2 done'), findsOneWidget);
    });

    testWidgets('ThingsHubScreen displays filter chips, hero, and wrapup mode', (tester) async {
      final activity = makeActivity(
        id: 'task_hub_1',
        title: 'Deep work on algorithms',
        kind: ActivityKind.duration,
        targetMinutes: 45,
        linkedTaskId: 10,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          todayActivitiesProvider.overrideWith(
            (ref) => Stream.value([activity]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const ThingsHubScreen(initialMode: 'wrapup'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter chips should be visible
      expect(find.widgetWithText(GlassChip, 'All activities'), findsOneWidget);
      expect(find.widgetWithText(GlassChip, 'To-dos'), findsOneWidget);
      expect(find.widgetWithText(GlassChip, 'Timers'), findsOneWidget);
      expect(find.widgetWithText(GlassChip, 'Medicines'), findsOneWidget);

      // Hero card should be rendered on Now tab
      expect(find.text('Deep work on algorithms'), findsOneWidget);

      // Evening wrap-up card should be present
      expect(find.text('Evening Wrap-up'), findsOneWidget);
      expect(find.text('Carry over to tomorrow'), findsOneWidget);
    });
  });

  group('Button Accessibility & Semantics', () {
    testWidgets('AscentButton announces busy and exposes Semantics onTap action', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: Center(
              child: AscentButton.primary(
                label: 'Save Changes',
                loading: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Semantic label should include busy announcement
      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label?.contains('busy') ?? false),
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('Things hub components fit 320px width at 2.0x text scale without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final activity = makeActivity(
        id: 'acc_task',
        title: 'Long activity title for accessibility audit verification',
        kind: ActivityKind.duration,
        targetMinutes: 30,
        linkedTaskId: 5,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          todayActivitiesProvider.overrideWith(
            (ref) => Stream.value([activity]),
          ),
        ],
      );
      addTearDown(container.dispose);

      for (final dark in [false, true]) {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
              ),
              child: MaterialApp(
                theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                home: const ThingsHubScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ThingsHeroCard), findsOneWidget);
      }
    });
  });
}
