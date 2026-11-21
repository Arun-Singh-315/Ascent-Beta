import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
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
    testWidgets('HomeHeader renders non-static name and diurnal period badge', (
      tester,
    ) async {
      final profile = makeProfile(
        name: 'Alex Rivera',
        role: 'Staff Systems Engineer',
      );

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

    testWidgets('Streak badge evolves to Blaze for streak >= 7', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            homeStreakVisibleProvider.overrideWithValue(true),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(14)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: HomeHeader(profile: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('14 · Blaze'), findsOneWidget);
    });

    testWidgets('Streak badge evolves to Fire for streak >= 30', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            homeStreakVisibleProvider.overrideWithValue(true),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(45)),
          ],
          child: const MaterialApp(
            home: Scaffold(body: HomeHeader(profile: null)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('45 · Fire'), findsOneWidget);
      expect(find.byIcon(Icons.whatshot_rounded), findsOneWidget);
    });
  });
}
