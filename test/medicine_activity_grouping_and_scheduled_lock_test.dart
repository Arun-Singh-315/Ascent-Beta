import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
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
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Medicine Activity Grouping Tests', () {
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
                body: ActivityRowItem(activity: futureActivity, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The "Done" button should NOT be present!
        expect(
          find.byKey(const ValueKey('activity_action_task_future')),
          findsNothing,
        );

        // The scheduled time badge should be visible
        expect(
          find.byKey(const ValueKey('activity_scheduled_task_future')),
          findsOneWidget,
        );

        // Tapping the scheduled badge displays the explanatory snackbar
        await tester.tap(
          find.byKey(const ValueKey('activity_scheduled_task_future')),
        );
        await tester.pump();

        expect(find.textContaining('Scheduled for'), findsOneWidget);
        expect(
          find.textContaining('You can complete it once that time arrives'),
          findsOneWidget,
        );
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
                body: ActivityRowItem(activity: dueActivity, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The "Done" button SHOULD be present when time has arrived!
        expect(
          find.byKey(const ValueKey('activity_action_task_due')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('activity_scheduled_task_due')),
          findsNothing,
        );
      },
    );

    testWidgets(
      // To-dos can be completed early; a medicine dose still waits.
      'Standard ActivityRowItem check target blocks an early medicine dose',
      (tester) async {
        final futureTime = DateTime.now().add(const Duration(hours: 2));
        final futureActivity = TodayActivityItem(
          id: 'task_future_std',
          title: 'Evening dose',
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
                body: ActivityRowItem(activity: futureActivity, compact: false),
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
                body: ActivityRowItem(activity: futureActivity, compact: false),
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
  });
}
