import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/plan_collection_service.dart';
import 'package:ascent/features/plans/planning_providers.dart';
import 'package:ascent/features/plans/widgets/home_plans_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final dummyStudyPlan = PlanCollectionView({
    'id': 'plan_study_1',
    'title': 'DSA Mastery 7-Day Sprint',
    'description': 'study: Daily leetcode and data structures curriculum',
    'status': 'active',
    'total': 7,
    'done': 3,
    'scheduled': 7,
    'skipped': 0,
    'routines': 1,
    'unscheduled': 0,
    'overdue': 0,
    'next_at': DateTime.now().add(const Duration(hours: 3)).millisecondsSinceEpoch ~/ 1000,
    'pending_alerts': 0,
  });

  final dummyMealPlan = PlanCollectionView({
    'id': 'plan_meal_1',
    'title': 'High Protein Clean Diet',
    'description': 'meal: 4 clean meals daily with protein & hydration',
    'status': 'active',
    'total': 4,
    'done': 2,
    'scheduled': 4,
    'skipped': 0,
    'routines': 1,
    'unscheduled': 0,
    'overdue': 0,
    'next_at': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
    'pending_alerts': 0,
  });

  testWidgets(
    'HomePlansPreview displays Study and Meal badges and quick planners',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            planCollectionsProvider.overrideWith(
              (ref) => Stream.value([dummyStudyPlan, dummyMealPlan]),
            ),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: HomePlansPreview(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Category Filter chips
      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('📚 Study (1)'), findsOneWidget);
      expect(find.text('🥗 Meal (1)'), findsOneWidget);

      // Check Cards and Badges
      expect(find.text('STUDY'), findsOneWidget);
      expect(find.text('DSA Mastery 7-Day Sprint'), findsOneWidget);
      expect(find.text('3/7 done'), findsOneWidget);

      expect(find.text('MEAL & DIET'), findsOneWidget);
      expect(find.text('High Protein Clean Diet'), findsOneWidget);
      expect(find.text('2/4 done'), findsOneWidget);

      // Check Quick Starters
      expect(find.text('Plan Study'), findsOneWidget);
      expect(find.text('Plan Meals'), findsOneWidget);

      // Tap Study filter chip
      await tester.tap(find.text('📚 Study (1)'));
      await tester.pumpAndSettle();

      expect(find.text('DSA Mastery 7-Day Sprint'), findsOneWidget);
      expect(find.text('High Protein Clean Diet'), findsNothing);

      // Tap Meal filter chip
      await tester.tap(find.text('🥗 Meal (1)'));
      await tester.pumpAndSettle();

      expect(find.text('DSA Mastery 7-Day Sprint'), findsNothing);
      expect(find.text('High Protein Clean Diet'), findsOneWidget);
    },
  );

  testWidgets(
    'HomePlansPreview satisfies Rule 13 overflow immunity at 320px with 2.0x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            planCollectionsProvider.overrideWith(
              (ref) => Stream.value([dummyStudyPlan, dummyMealPlan]),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: HomePlansPreview(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero exceptions and zero RenderFlex overflow
      expect(tester.takeException(), isNull);
      expect(find.text('Plan Study'), findsOneWidget);
      expect(find.text('Plan Meals'), findsOneWidget);
    },
  );
}
