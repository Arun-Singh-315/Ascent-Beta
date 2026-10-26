import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/medicine_activity_group_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdleTracking extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _IdleLearning extends LearningHubNotifier {
  @override
  LearningHubState build() => const LearningHubState(
    courses: [],
    activeCourseId: '',
    activeLectureId: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(_IdleTracking.new),
        learningHubProvider.overrideWith(_IdleLearning.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Medicine Activity Grouping Tests', () {
    testWidgets(
      'ActivityHubCard groups multiple medicine doses into a single MedicineActivityGroupCard',
      (tester) async {
        final now = DateTime.now();
        final dose9am = TodayActivityItem(
          id: 'task_1',
          title: 'Paracetamol (medicine) (500mg) — 9:00 AM',
          sourceType: 'medicine',
          status: TodayActivityStatus.done,
          elapsedSecondsToday: 0,
          categoryTag: 'Medicine',
          medicineId: 1,
          timeSlot: '09:00',
          scheduledTime: DateTime(now.year, now.month, now.day, 9, 0),
        );
        final dose2pm = TodayActivityItem(
          id: 'task_2',
          title: 'Paracetamol (medicine) (500mg) — 2:00 PM',
          sourceType: 'medicine',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          categoryTag: 'Medicine',
          medicineId: 1,
          timeSlot: '14:00',
          scheduledTime: DateTime(now.year, now.month, now.day, 14, 0),
        );
        final dose8pm = TodayActivityItem(
          id: 'task_3',
          title: 'Paracetamol (medicine) (500mg) — 8:00 PM',
          sourceType: 'medicine',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          categoryTag: 'Medicine',
          medicineId: 1,
          timeSlot: '20:00',
          scheduledTime: DateTime(now.year, now.month, now.day, 20, 0),
        );
        final regularTask = TodayActivityItem(
          id: 'task_4',
          title: 'Study Flutter state management',
          sourceType: 'task',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          categoryTag: 'Task',
        );

        final items = [dose9am, dose2pm, dose8pm, regularTask];

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: ProviderScope(
              overrides: [
                todayActivitiesProvider.overrideWith(
                  (ref) => Stream.value(items),
                ),
              ],
              child: MaterialApp(
                theme: AscentTheme.light(),
                home: const Scaffold(
                  body: SingleChildScrollView(
                    child: ActivityHubCard(previewLimit: 4),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify only 1 MedicineActivityGroupCard is rendered, NOT 3 separate rows!
        expect(find.byType(MedicineActivityGroupCard), findsOneWidget);
        // Verify 1 regular ActivityRowItem is rendered alongside it
        expect(find.byType(ActivityRowItem), findsOneWidget);

        // Verify group card displays medicine name and summary
        expect(find.text('Paracetamol (500mg)'), findsOneWidget);
        expect(find.textContaining('1 of 3 taken'), findsOneWidget);

        // Individual doses should NOT be visible until expanded
        expect(find.byKey(const ValueKey('group_dose_task_2')), findsNothing);

        // Tap the medicine group to expand it
        await tester.tap(find.byKey(const ValueKey('medicine_group_Paracetamol')));
        await tester.pumpAndSettle();

        // All 3 doses should now be visible inline
        expect(find.byKey(const ValueKey('group_dose_task_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('group_dose_task_2')), findsOneWidget);
        expect(find.byKey(const ValueKey('group_dose_task_3')), findsOneWidget);

        // Tap again to collapse
        await tester.tap(find.byKey(const ValueKey('medicine_group_Paracetamol')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('group_dose_task_2')), findsNothing);
      },
    );
  });

  group('Premature Done Lock on Scheduled Activities Tests', () {
    testWidgets(
      'Activity scheduled in future shows scheduled badge instead of Done button',
      (tester) async {
        // Scheduled 3 hours into the future
        final futureTime = DateTime.now().add(const Duration(hours: 3));
        final futureActivity = TodayActivityItem(
          id: 'task_future',
          title: 'Take Afternoon Medicine',
          sourceType: 'medicine',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          categoryTag: 'Medicine',
          scheduledTime: futureTime,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(
                  activity: futureActivity,
                  compact: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The "Done" button should NOT be present!
        expect(find.byKey(const ValueKey('activity_action_task_future')), findsNothing);

        // The scheduled time badge should be visible
        expect(
          find.byKey(const ValueKey('activity_scheduled_task_future')),
          findsOneWidget,
        );

        // Tapping the scheduled badge displays the explanatory snackbar
        await tester.tap(find.byKey(const ValueKey('activity_scheduled_task_future')));
        await tester.pump();

        expect(find.textContaining('Scheduled for'), findsOneWidget);
        expect(find.textContaining('You can complete it once that time arrives'), findsOneWidget);
      },
    );

    testWidgets(
      'Activity scheduled in past/due displays the Done button and allows completion',
      (tester) async {
        // Scheduled 1 hour in the past (already due)
        final pastTime = DateTime.now().subtract(const Duration(hours: 1));
        final dueActivity = TodayActivityItem(
          id: 'task_due',
          title: 'Morning Medicine',
          sourceType: 'medicine',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          categoryTag: 'Medicine',
          scheduledTime: pastTime,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(
                  activity: dueActivity,
                  compact: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The "Done" button SHOULD be present when time has arrived!
        expect(find.byKey(const ValueKey('activity_action_task_due')), findsOneWidget);
        expect(find.byKey(const ValueKey('activity_scheduled_task_due')), findsNothing);
      },
    );

    testWidgets(
      'Standard ActivityRowItem circular check target blocks premature completion on future scheduled task',
      (tester) async {
        final futureTime = DateTime.now().add(const Duration(hours: 2));
        final futureActivity = TodayActivityItem(
          id: 'task_future_std',
          title: 'Doctor Appointment',
          sourceType: 'task',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          categoryTag: 'Task',
          scheduledTime: futureTime,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(
                  activity: futureActivity,
                  compact: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify clock icon is visible in circular target
        expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);

        // Tap circular target
        await tester.tap(find.byIcon(Icons.schedule_rounded));
        await tester.pump();

        // Explanatory snackbar is shown
        expect(find.textContaining('Scheduled for'), findsOneWidget);
      },
    );

    testWidgets(
      'ActivityRowItem detail dialog shows Scheduled button instead of Mark Done for future scheduled task',
      (tester) async {
        final futureTime = DateTime.now().add(const Duration(hours: 4));
        final futureActivity = TodayActivityItem(
          id: 'task_future_dialog',
          title: 'Evening Medicine',
          sourceType: 'medicine',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          categoryTag: 'Medicine',
          scheduledTime: futureTime,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(
                  activity: futureActivity,
                  compact: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the title to open detail dialog
        await tester.tap(find.text('Evening Medicine'));
        await tester.pumpAndSettle();

        // "Mark Done" should NOT be present!
        expect(find.text('Mark Done'), findsNothing);

        // "Scheduled · ..." should be present
        expect(find.textContaining('Scheduled ·'), findsOneWidget);

        // Tapping it should dismiss dialog and show explanatory snackbar
        await tester.tap(find.textContaining('Scheduled ·'));
        await tester.pump();

        expect(find.textContaining('Scheduled for'), findsOneWidget);
      },
    );
  });

  group('Accessibility & Boundary Tests (Rule 13)', () {
    testWidgets(
      'MedicineActivityGroupCard renders cleanly without RenderFlex overflows at 320px with 2.0x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final now = DateTime.now();
        final activities = [
          TodayActivityItem(
            id: 'dose_1',
            title: 'Long Medicine Name Tablet (1000mg) — 9:00 AM',
            sourceType: 'medicine',
            status: TodayActivityStatus.notStarted,
            elapsedSecondsToday: 0,
            categoryTag: 'Medicine',
            scheduledTime: DateTime(now.year, now.month, now.day, 9, 0),
          ),
          TodayActivityItem(
            id: 'dose_2',
            title: 'Long Medicine Name Tablet (1000mg) — 2:00 PM',
            sourceType: 'medicine',
            status: TodayActivityStatus.notStarted,
            elapsedSecondsToday: 0,
            categoryTag: 'Medicine',
            scheduledTime: DateTime(now.year, now.month, now.day, 14, 0),
          ),
        ];

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MedicineActivityGroupCard(
                    medicineName: 'Long Medicine Name Tablet',
                    dosage: '1000mg',
                    activities: activities,
                    compact: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify zero exceptions
        expect(tester.takeException(), isNull);

        // Tap to expand
        await tester.tap(find.byKey(const ValueKey('medicine_group_Long Medicine Name Tablet')));
        await tester.pumpAndSettle();

        // Verify zero exceptions even when expanded at 320px with 2.0x text scale
        expect(tester.takeException(), isNull);
      },
    );
  });
}
