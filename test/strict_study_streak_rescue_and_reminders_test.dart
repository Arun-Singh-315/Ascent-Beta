import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/auth/auth_provider.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/home_dismissible_reminders_section.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/study_streak_meter_card.dart';

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(isAuthenticated: true, username: 'testuser');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Strict Study Streak & Rescue Math Logic Tests', () {
    test(
      'Anti-Cheat: Manual lecture completion does not increment study watch time',
      () {
        final calculator = StudyStreakCalculator();
        final now = DateTime(2026, 10, 8, 14, 0);

        // User has 0 seconds watched
        final status = calculator.calculate(
          todaySeconds: 0,
          yesterdaySeconds: 7200, // Yesterday met 2 hours
          priorStreakDays: 3,
          historicalLongestStreak: 5,
          now: now,
        );

        expect(status.todaySeconds, 0);
        expect(status.todayMinutes, 0);
        expect(status.isTodaySecured, isFalse);
        expect(status.progressFraction, 0.0);
        // Streak from yesterday is alive, but today is not yet secured
        expect(status.displayStreakDays, 3);
        expect(status.isRescueMode, isFalse);
      },
    );

    test(
      'Normal Goal: Completing 120 minutes (7200s) secures today and increments streak',
      () {
        final calculator = StudyStreakCalculator();
        final now = DateTime(2026, 10, 8, 15, 30);

        final status = calculator.calculate(
          todaySeconds: 7200, // Exactly 120 minutes
          yesterdaySeconds: 7200,
          priorStreakDays: 4,
          historicalLongestStreak: 4,
          now: now,
        );

        expect(status.isTodaySecured, isTrue);
        expect(status.displayStreakDays, 5); // 4 + 1
        expect(status.progressFraction, 1.0);
        expect(status.remainingMinutes, 0);
        expect(status.longestStreakDays, 5);
        expect(status.isRescueMode, isFalse);
      },
    );

    test(
      'Rescue Mode: Deficit from yesterday is added to today requirement (1-day grace)',
      () {
        final calculator = StudyStreakCalculator();
        final now = DateTime(2026, 10, 8, 11, 0);

        // Yesterday user only studied 80 minutes (4800s), missing 40 minutes (2400s)
        final status = calculator.calculate(
          todaySeconds: 3600, // 60 mins studied so far today
          yesterdaySeconds: 4800, // 80 mins
          priorStreakDays: 6, // Had a 6-day streak
          historicalLongestStreak: 10,
          now: now,
        );

        expect(status.isRescueMode, isTrue);
        expect(status.yesterdayDeficitMinutes, 40);
        // Today target is 120m + 40m debt = 160 minutes
        expect(status.targetMinutes, 160);
        expect(status.todayMinutes, 60);
        expect(status.remainingMinutes, 100);
        expect(status.isTodaySecured, isFalse);
        // Prior streak of 6 is preserved in rescue mode until midnight
        expect(status.displayStreakDays, 6);
      },
    );

    test(
      'Rescue Mode: Successfully hitting target today rescues the streak',
      () {
        final calculator = StudyStreakCalculator();
        final now = DateTime(2026, 10, 8, 20, 0);

        // Today watched 160 minutes (9600s), fully paying off the 40m debt
        final status = calculator.calculate(
          todaySeconds: 9600,
          yesterdaySeconds: 4800, // 80 mins
          priorStreakDays: 6,
          historicalLongestStreak: 10,
          now: now,
        );

        expect(status.isRescueMode, isTrue);
        expect(status.isTodaySecured, isTrue);
        expect(status.isRescuedToday, isTrue);
        // Rescued streak preserved!
        expect(status.displayStreakDays, 7);
        expect(status.remainingMinutes, 0);
        expect(status.progressFraction, 1.0);
      },
    );

    test(
      'Snapchat-style Urgency: Alerts user in the evening if minutes are still remaining',
      () {
        final calculator = StudyStreakCalculator();
        // 8:00 PM (20:00) with 45 minutes remaining
        final eveningTime = DateTime(2026, 10, 8, 20, 0);

        final status = calculator.calculate(
          todaySeconds: 4500, // 75 mins watched, 45 mins left
          yesterdaySeconds: 7200,
          priorStreakDays: 3,
          historicalLongestStreak: 5,
          now: eveningTime,
        );

        expect(status.isTodaySecured, isFalse);
        expect(status.remainingMinutes, 45);
        expect(status.isUrgent, isTrue);
        expect(status.hoursRemainingInDay, 4); // 24 - 20 = 4
      },
    );

    test(
      'Snapchat-style Urgency: Not urgent in morning/afternoon with time remaining',
      () {
        final calculator = StudyStreakCalculator();
        // 11:00 AM (11:00)
        final morningTime = DateTime(2026, 10, 8, 11, 0);

        final status = calculator.calculate(
          todaySeconds: 3600,
          yesterdaySeconds: 7200,
          priorStreakDays: 3,
          historicalLongestStreak: 5,
          now: morningTime,
        );

        expect(status.isUrgent, isFalse);
      },
    );
  });

  group('Study Streak Meter UI Widget Tests', () {
    testWidgets(
      'StudyStreakMeterCard renders real-time progress and streak stats cleanly',
      (tester) async {
        final mockStatus = StudyStreakStatus(
          todaySeconds: 4500, // 75 mins
          targetSeconds: 7200, // 120 mins
          priorStreakDays: 5,
          currentStreakDays: 5,
          displayStreakDays: 5,
          longestStreakDays: 12,
          shortestStreakDays: 1,
          isTodaySecured: false,
          isRescueMode: false,
          isRescuedToday: false,
          yesterdayDeficitSeconds: 0,
          isUrgent: false,
          hoursRemainingInDay: 10,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: Scaffold(
              body: StudyStreakMeterCard(status: mockStatus, onTap: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('75'), findsWidgets);
        expect(find.textContaining('120'), findsWidgets);
        expect(find.textContaining('5'), findsWidgets);
        expect(find.textContaining('Longest: 12d'), findsOneWidget);
      },
    );

    testWidgets(
      'StudyStreakMeterCard shows urgent alert banner when streak is at risk in the evening',
      (tester) async {
        final urgentStatus = StudyStreakStatus(
          todaySeconds: 4500, // 75 mins
          targetSeconds: 7200, // 120 mins
          priorStreakDays: 4,
          currentStreakDays: 4,
          displayStreakDays: 4,
          longestStreakDays: 8,
          shortestStreakDays: 1,
          isTodaySecured: false,
          isRescueMode: false,
          isRescuedToday: false,
          yesterdayDeficitSeconds: 0,
          isUrgent: true,
          hoursRemainingInDay: 3,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: Scaffold(
              body: StudyStreakMeterCard(status: urgentStatus, onTap: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('continue your streak today'),
          findsOneWidget,
        );
        expect(find.textContaining('45m of study'), findsOneWidget);
      },
    );

    testWidgets(
      'StudyStreakMeterCard shows Rescue banner when yesterday was missed and debt is active',
      (tester) async {
        final rescueStatus = StudyStreakStatus(
          todaySeconds: 1800, // 30 mins
          targetSeconds: 9600, // 160 mins (120m + 40m debt)
          priorStreakDays: 7,
          currentStreakDays: 7,
          displayStreakDays: 7,
          longestStreakDays: 14,
          shortestStreakDays: 1,
          isTodaySecured: false,
          isRescueMode: true,
          isRescuedToday: false,
          yesterdayDeficitSeconds: 2400, // 40 mins debt
          isUrgent: false,
          hoursRemainingInDay: 8,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: Scaffold(
              body: StudyStreakMeterCard(status: rescueStatus, onTap: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('recover your streak'), findsOneWidget);
        expect(find.textContaining('160m of study'), findsOneWidget);
      },
    );
  });

  group('Home Screen Dismissible Reminders Tests', () {
    testWidgets(
      'HomeDismissibleRemindersSection renders upcoming reminders read-only',
      (tester) async {
        bool dismissed = false;

        final reminders = [
          Reminder(
            id: 101,
            title: 'Review System Design Chapter 3',
            scheduledAt: DateTime.now().add(const Duration(hours: 2)),
            isActive: true,
            linkedTaskId: null,
            createdAt: DateTime.now(),
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: Scaffold(
              body: HomeDismissibleRemindersSection(
                reminders: reminders,
                onDismissReminder: (reminder) async {
                  dismissed = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Review System Design Chapter 3'), findsOneWidget);

        // Perform swipe to dismiss
        await tester.drag(
          find.text('Review System Design Chapter 3'),
          const Offset(-500, 0),
        );
        await tester.pumpAndSettle();

        expect(dismissed, isFalse);
        expect(find.byType(Dismissible), findsNothing);
      },
    );

    testWidgets('HomeDismissibleRemindersSection hides all empty reminder UI', (
      tester,
    ) async {
      bool addPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.dark(),
          home: Scaffold(
            body: HomeDismissibleRemindersSection(
              reminders: const [],
              onDismissReminder: (_) async {},
              onAddReminder: () {
                addPressed = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Text), findsNothing);
      expect(addPressed, isFalse);
    });

    testWidgets(
      'Rule 7 Capping: HomeDismissibleRemindersSection only renders 1 primary reminder even if 7 exist, with +X more chip',
      (tester) async {
        bool viewAllTriggered = false;

        final sevenReminders = List.generate(
          7,
          (i) => Reminder(
            id: i + 1,
            title: 'Reminder #$i',
            scheduledAt: DateTime.now().add(Duration(minutes: (i + 1) * 15)),
            isActive: true,
            linkedTaskId: null,
            createdAt: DateTime.now(),
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: Scaffold(
              body: HomeDismissibleRemindersSection(
                reminders: sevenReminders,
                onDismissReminder: (_) async {},
                onViewAll: () {
                  viewAllTriggered = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only the first (primary) reminder should be rendered as a card
        expect(find.text('Reminder #0'), findsOneWidget);
        expect(find.text('Reminder #1'), findsNothing);
        expect(find.text('Reminder #2'), findsNothing);
        expect(find.text('Reminder #6'), findsNothing);

        // Total count badge should show 7

        // Overflow indicator removed per feedback; tapping the card triggers navigation
        expect(find.text('+6 more reminders inside • View all'), findsNothing);

        // Tapping the reminder card triggers navigation to full reminders screen
        await tester.tap(find.text('Reminder #0'));
        await tester.pumpAndSettle();
        expect(viewAllTriggered, isTrue);
      },
    );
  });

  group('Study Streak Card Visibility Toggle Tests', () {
    test(
      'StudyStreakCardVisibilityNotifier defaults to true and toggles cleanly',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(studyStreakCardVisibleProvider), isTrue);

        container.read(studyStreakCardVisibleProvider.notifier).toggle();
        expect(container.read(studyStreakCardVisibleProvider), isFalse);

        container.read(studyStreakCardVisibleProvider.notifier).toggle();
        expect(container.read(studyStreakCardVisibleProvider), isTrue);
      },
    );

    testWidgets(
      'HomeHeader streak flame pill tap toggles studyStreakCardVisibleProvider',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(5)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: HomeHeader(profile: null)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(studyStreakCardVisibleProvider), isTrue);

        // Tap on the streak pill in the header
        await tester.tap(find.byIcon(Icons.local_fire_department_rounded));
        await tester.pumpAndSettle();

        // Card visibility should now be toggled to false (hidden)
        expect(container.read(studyStreakCardVisibleProvider), isFalse);

        // Tap again to restore
        await tester.tap(find.byIcon(Icons.local_fire_department_rounded));
        await tester.pumpAndSettle();
        expect(container.read(studyStreakCardVisibleProvider), isTrue);
      },
    );
  });
}
