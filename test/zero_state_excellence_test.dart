import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/plan_collection_service.dart';
import 'package:ascent/features/home/widgets/home_promise_section.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/plans/planning_providers.dart';
import 'package:ascent/features/plans/widgets/home_plans_preview.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
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

  testWidgets(
    'HomePromiseSection displays quiet sanctuary empty state when promises are empty',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activePromisesStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: HomePromiseSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Promises'), findsOneWidget);
      expect(find.text('No active promises'), findsOneWidget);
      expect(
        find.text('Make a realistic commitment to yourself'),
        findsOneWidget,
      );
      expect(find.text('+ Promise'), findsNothing);
    },
  );

  testWidgets(
    'HomePlansPreview displays unified glass empty state when plans are empty',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            planCollectionsProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: HomePlansPreview()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Recurring Plans Yet'), findsOneWidget);
      expect(
        find.text(
          'Design routines, weekly rhythms, and habits that organize your days automatically.',
        ),
        findsOneWidget,
      );
      expect(find.text('Create a plan'), findsOneWidget);
    },
  );

  testWidgets(
    'ThoughtWallHomePreview renders thought spark chips when thoughts are empty',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            latestHomeThoughtProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(compact: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Spark an idea'), findsOneWidget);
      expect(find.text('Log a win'), findsOneWidget);
      expect(find.text('Reflect'), findsOneWidget);

      // Tap 'Spark an idea' and verify composer pre-fills
      await tester.tap(find.text('Spark an idea'));
      await tester.pump();
      expect(find.text('💡 '), findsOneWidget);
    },
  );

  testWidgets(
    'Zero-state views pass Rule 13 overflow immunity at 320px with 2.0x font scaling',
    (tester) async {
      tester.view.physicalSize = const Size(320 * 3.0, 800 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            activePromisesStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            planCollectionsProvider.overrideWith((ref) => Stream.value([])),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            latestHomeThoughtProvider.overrideWith((ref) => Stream.value(null)),
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
                  child: Column(
                    children: [
                      HomePromiseSection(),
                      SizedBox(height: 16),
                      HomePlansPreview(),
                      SizedBox(height: 16),
                      ThoughtWallHomePreview(compact: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('No active promises'), findsOneWidget);
      expect(find.text('No Recurring Plans Yet'), findsOneWidget);
    },
  );
}
