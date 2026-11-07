import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/home_day_glance_card.dart';
import 'package:ascent/features/home/widgets/home_executive_focus_card.dart';
import 'package:ascent/features/home/widgets/home_top_reminders_glance.dart';
import 'package:ascent/features/home/widgets/home_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  UserProfile makeProfile({required String name, required String role}) {
    final now = DateTime.now();
    return UserProfile(
      id: 1,
      name: name,
      targetRole: role,
      targetCompanies: '[]',
      weeklyHoursAvailable: 20,
      preferredStudyWindow: 'morning',
      skillSelfRatings: '{}',
      createdAt: now,
      updatedAt: now,
      onboardingComplete: true,
    );
  }

  group('iOS Home Elevation & Dynamic Greeting Tests', () {
    testWidgets('HomeHeader renders non-static name and diurnal period badge', (tester) async {
      final profile = makeProfile(name: 'Alex Rivera', role: 'Staff Systems Engineer');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            homeStreakVisibleProvider.overrideWithValue(true),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(5)),
          ],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: HomeHeader(profile: profile),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify name is rendered and findable
      expect(find.text('Alex Rivera'), findsOneWidget);
      expect(find.byKey(const ValueKey('home_user_name')), findsOneWidget);

      // Verify streak badge shows heat level for 5 days
      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });

    testWidgets('Streak badge evolves to Blaze for streak >= 7', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            homeStreakVisibleProvider.overrideWithValue(true),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(14)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HomeHeader(profile: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('14 · Blaze'), findsOneWidget);
    });

    testWidgets('Streak badge evolves to Fire for streak >= 30', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            homeStreakVisibleProvider.overrideWithValue(true),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(45)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HomeHeader(profile: null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('45 · Fire'), findsOneWidget);
      expect(find.byIcon(Icons.whatshot_rounded), findsOneWidget);
    });

    testWidgets('HomeExecutiveFocusCard renders velocity track and telemetry trio metrics', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayActivitiesProvider.overrideWith(
              (ref) => Stream.value([
                const TodayActivityItem(
                  id: '1',
                  title: 'Architecture Review',
                  sourceType: 'task',
                  status: TodayActivityStatus.done,
                  elapsedSecondsToday: 0,
                  categoryTag: 'work',
                ),
                const TodayActivityItem(
                  id: '2',
                  title: 'Team Sync',
                  sourceType: 'task',
                  status: TodayActivityStatus.notStarted,
                  elapsedSecondsToday: 0,
                  categoryTag: 'meeting',
                ),
              ]),
            ),
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(1500)),
            dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2500)),
            todayMedicineLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HomeExecutiveFocusCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Card is present
      expect(find.byKey(const ValueKey('home_executive_focus_card')), findsOneWidget);

      // Verify dynamic headline: "1 of 2 priorities done"
      expect(find.text('1 of 2 priorities done'), findsOneWidget);

      // Verify telemetry chips
      expect(find.text('1/2'), findsOneWidget);
      expect(find.text('1.50L'), findsOneWidget);
    });

    testWidgets('Rule 13: Strict 320px width & 2.0x text scale overflow immunity', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.reset());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayActivitiesProvider.overrideWith(
              (ref) => Stream.value([
                const TodayActivityItem(
                  id: '1',
                  title: 'Core Task',
                  sourceType: 'task',
                  status: TodayActivityStatus.notStarted,
                  elapsedSecondsToday: 0,
                  categoryTag: 'work',
                ),
              ]),
            ),
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(750)),
            dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2500)),
            todayMedicineLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: ListView(
                  children: [
                    HomeHeader(
                      profile: makeProfile(
                        name: 'Long Firstname Supercalifragilistic',
                        role: 'Executive Principal Architect',
                      ),
                    ),
                    const HomeTopRemindersGlance(),
                    const HomeExecutiveFocusCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Zero exceptions and zero RenderFlex overflow errors
      expect(tester.takeException(), isNull);
    });
  });
}
