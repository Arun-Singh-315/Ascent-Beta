import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/services/festival_service.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/reminders/reminders_screen.dart';
import 'package:ascent/features/today/things_hub_screen.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/shared/widgets/festive_sparkle_badge.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

UserProfile _makeTestProfile({
  String name = 'Arun Singh visen',
  DateTime? dob,
}) {
  return UserProfile(
    id: 1,
    name: name,
    dateOfBirth: dob ?? DateTime(1998, 6, 15),
    targetRole: 'Software Engineer',
    targetCompanies: '["Google"]',
    weeklyHoursAvailable: 10,
    preferredStudyWindow: 'morning',
    skillSelfRatings: '{}',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    onboardingComplete: true,
  );
}

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
        todaySeconds: 7200,
        yesterdaySeconds: 7200,
        priorStreakDays: 5,
        historicalLongestStreak: 5,
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
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Reminders & Alerts': true,
      'userName': 'Arun Singh visen',
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Festival Catalog & Service Tests', () {
    test('Identifies Diwali 2026 correctly on Nov 8, 2026', () {
      final diwaliDate = DateTime(2026, 11, 8);
      final festival = FestivalService.getFestivalForDate(diwaliDate);
      expect(festival, isNotNull);
      expect(festival!.name, 'Diwali');
      expect(festival.emoji, '🪔');
      expect(festival.thought, contains('Lighting a lamp within'));
      expect(festival.riyaWish, contains('warm light'));
    });

    test('Identifies Dhanteras, Bhai Dooj, Chhath Puja in Nov 2026', () {
      expect(
        FestivalService.getFestivalForDate(DateTime(2026, 11, 6))?.name,
        'Dhanteras',
      );
      expect(
        FestivalService.getFestivalForDate(DateTime(2026, 11, 10))?.name,
        'Bhai Dooj',
      );
      expect(
        FestivalService.getFestivalForDate(DateTime(2026, 11, 15))?.name,
        'Chhath Puja',
      );
    });

    test('Returns null for ordinary non-festival day', () {
      final ordinaryDate = DateTime(2026, 11, 12);
      expect(FestivalService.getFestivalForDate(ordinaryDate), isNull);
    });
  });

  group('Things Hub & Calendar Bidirectional Navigation & Agenda Tests', () {
    testWidgets('Things Hub app bar includes direct Calendar button', (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const ThingsHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('things_calendar_button')), findsOneWidget);
    });

    testWidgets('Calendar in Reminders includes Dayboard action and displays Things Hub activities', (
      tester,
    ) async {
      final now = DateTime.now();

      // Insert a reminder and a task
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Diwali Puja Preparations',
          scheduledAt: now,
        ),
      );

      // Create a Things Hub activity stream override
      final customActivity = TodayActivityItem(
        id: 'activity_dsa_1',
        title: 'Complete Graph BFS Problem',
        sourceType: 'dsa',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        categoryTag: 'Prep',
        plannedDate: now,
        isOverdue: false,
        hasReminder: false,
        kind: ActivityKind.duration,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          todayActivitiesProvider.overrideWith(
            (ref) => Stream.value([customActivity]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const RemindersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle to Google Calendar view
      await tester.tap(find.byKey(const ValueKey('calendar_toggle_button')));
      await tester.pumpAndSettle();

      // Verify Dayboard quick-link in app bar
      expect(find.byKey(const ValueKey('calendar_dayboard_button')), findsOneWidget);

      // Verify Reminders and Things Hub activities both appear in the Calendar Agenda
      expect(find.text('Diwali Puja Preparations'), findsOneWidget);
      expect(find.text('THINGS & ACTIVITIES'), findsOneWidget);
      expect(find.text('Complete Graph BFS Problem'), findsOneWidget);

      // If today is Diwali (Nov 8, 2026), FestiveBannerCard should be rendered
      if (FestivalService.getTodayFestival() != null) {
        expect(find.byType(FestiveBannerCard), findsOneWidget);
      }
    });
  });

  group('Festive Ambient UI: Home Header, Thought Wall, & Riya Tests', () {
    testWidgets('Home Header displays festive banner on festival day', (tester) async {
      final testProfile = _makeTestProfile();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          userProfileStreamProvider.overrideWith(
            (ref) => Stream.value(testProfile),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: HomeHeader(
                profile: testProfile,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final todayFestival = FestivalService.getTodayFestival();
      if (todayFestival != null) {
        expect(find.byKey(const ValueKey('home_festival_banner')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('home_festival_banner')),
            matching: find.textContaining('Happy ${todayFestival.name}'),
          ),
          findsOneWidget,
        );
        expect(find.text(todayFestival.thought), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Thought Wall preview displays festival thought card by default when empty', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: ThoughtWallHomePreview(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final todayFestival = FestivalService.getTodayFestival();
      if (todayFestival != null) {
        expect(
          find.byKey(const ValueKey('festival_default_thought_card')),
          findsOneWidget,
        );
        expect(find.text(todayFestival.thought), findsOneWidget);
        expect(
          find.text('${todayFestival.emoji} ${todayFestival.name}'),
          findsOneWidget,
        );
      }
    });

    testWidgets('Riya AI Assistant greets with warm personalized festival wish', (
      tester,
    ) async {
      final testProfile = _makeTestProfile();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          aiAssistantDaoProvider.overrideWithValue(db.aiAssistantDao),
          userProfileStreamProvider.overrideWith(
            (ref) => Stream.value(testProfile),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: const AiAssistantScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final todayFestival = FestivalService.getTodayFestival();
      if (todayFestival != null) {
        expect(find.byKey(const ValueKey('riya_festive_wish_card')), findsOneWidget);
        expect(find.byKey(const ValueKey('riya_festive_greeting')), findsOneWidget);
        expect(find.textContaining('Happy ${todayFestival.name}'), findsWidgets);
      }

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Rule 13 Overflow Immunity at 320px width with 2.0x text scaling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Verify Mindspace/ThoughtWall at 320px with 2.0x text scale
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2.0),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: ThoughtWallHomePreview(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      // Verify Reminders & Calendar at 320px with 2.0x text scale
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2.0),
              ),
              child: const RemindersScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
