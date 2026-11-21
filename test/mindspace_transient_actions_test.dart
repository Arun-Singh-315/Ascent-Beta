import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/home_header.dart';

class FakeStudyStreakNotifier extends StudyStreakNotifier {
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
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Thought Wall': true,
    });
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentStreakStreamProvider.overrideWith((ref) => Stream.value(0)),
        studyStreakProvider.overrideWith(FakeStudyStreakNotifier.new),
        homeStreakVisibleProvider.overrideWithValue(true),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget wrap(Widget child, {ThemeData? theme}) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: theme ?? AscentTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  group('Mind Space Home Preview Permanent Actions', () {
  });

  group('HomeHeader Transparent and Compact Styling', () {
    testWidgets('HomeHeader replaces Start with the assistant gateway', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const HomeHeader(profile: null), theme: AscentTheme.light()),
      );
      await tester.pumpAndSettle();

      // The assistant is reachable without floating over content.
      expect(find.text('Ask Riya'), findsOneWidget);

      expect(find.text('Start'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(minutes: 20));
    });
  });
}
