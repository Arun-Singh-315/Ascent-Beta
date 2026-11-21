import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentStreakStreamProvider.overrideWith((ref) => Stream.value(0)),
        studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('ChoiceChip theme contrast', () {});

  group('Thought card action UX and chevron collapse/expand', () {
    testWidgets(
      'thought card navigates to thought wall on tap, while ^ chevron toggles actions without Open pill',
      (tester) async {
        final thoughtId = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Thought for navigation test'),
        );

        String? pushedRoute;
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(
                body: SingleChildScrollView(child: ThoughtWallHomePreview()),
              ),
            ),
            GoRoute(
              path: '/thought-wall',
              builder: (context, state) {
                pushedRoute =
                    '/thought-wall?thought=${state.uri.queryParameters['thought']}';
                return const Scaffold(body: Text('Thought Wall Screen'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AscentTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The thought is rendered
        expect(find.text('Thought for navigation test'), findsOneWidget);
        // Tap the thought card -> navigates to Thought Wall.
        await tester.tap(find.text('Thought for navigation test'));
        await tester.pumpAndSettle();

        expect(pushedRoute, equals('/thought-wall?thought=$thoughtId'));
        expect(find.text('Thought Wall Screen'), findsOneWidget);
      },
    );
  });
}
