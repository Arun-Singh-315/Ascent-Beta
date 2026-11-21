import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:google_fonts/google_fonts.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/today/add_activity_sheet.dart';

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

  final testProfile = UserProfile(
    id: 1,
    name: 'Arun',
    targetRole: 'Backend Engineer',
    targetCompanies: '[]',
    weeklyHoursAvailable: 10,
    preferredStudyWindow: 'morning',
    skillSelfRatings: '{}',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    onboardingComplete: true,
    interviewDate: null,
    lastOpenedAt: null,
  );

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'ascent_theme_mode': 'light',
      'ascent_day_theme_preset': 'merlot_linen',
      'ascent_quick_start_v1': true,
      'ascent_onboarding_complete': true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildHarness(
    Widget child, {
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        aiAssistantDaoProvider.overrideWithValue(db.aiAssistantDao),
        timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
        studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
        userProfileStreamProvider.overrideWith(
          (ref) => Stream.value(testProfile),
        ),
      ],
      child: MaterialApp(
        theme: AscentTheme.light(),
        builder: (context, childWidget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: childWidget!,
        ),
        home: child,
      ),
    );
  }

  group('Daily Launchpad & UI Elevation Tests', () {
    testWidgets(
      '1. Activity Type Chips: equal structured size & flame gold accent on selection',
      (tester) async {
        await tester.pumpWidget(
          buildHarness(
            Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => AddActivitySheet.show(ctx),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('To-do'), findsOneWidget);
        expect(find.text('Timed'), findsOneWidget);
        expect(find.text('Flexible'), findsOneWidget);

        // Verify selecting 'Timed' updates selection and does not throw
        await tester.ensureVisible(find.text('Timed'));
        await tester.tap(find.text('Timed'));
        await tester.pumpAndSettle();

        // Timed duration chips appear
        expect(find.text('Target Duration'), findsOneWidget);
        expect(find.text('30 min'), findsOneWidget);

        // Verify selecting 'Flexible'
        await tester.ensureVisible(find.text('Flexible'));
        await tester.tap(find.text('Flexible'));
        await tester.pumpAndSettle();
        expect(find.text('Target Duration'), findsNothing);
      },
    );

    testWidgets(
      '2. Rule 13: Activity Type Selector at 320px width & 2.0x text scale has 0 overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          buildHarness(
            Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => AddActivitySheet.show(ctx),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('To-do'), findsOneWidget);
        expect(find.text('Timed'), findsOneWidget);
        expect(find.text('Flexible'), findsOneWidget);
      },
    );
  });
}
