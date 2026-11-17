import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/today/things_hub_screen.dart';
import 'package:drift/native.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

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
        taskDaoProvider.overrideWithValue(db.taskDao),
        thoughtDaoProvider.overrideWithValue(db.thoughtDao),
        studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Home Empty States & Centering Audit', () {
    testWidgets('ActivityHubCard empty state renders centered icon, title, subtitle, and starter chips', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ActivityHubCard(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify centered empty state title and subtitle
      expect(find.text('What’s on your mind today?'), findsOneWidget);
      expect(
        find.text('Add a task or timed focus block to build daily momentum.'),
        findsOneWidget,
      );

      // Verify centered starter action chips
      expect(find.byKey(const ValueKey('starter_add_task')), findsOneWidget);
      expect(find.byKey(const ValueKey('starter_add_timer')), findsOneWidget);
      expect(find.byIcon(Icons.checklist_rtl_rounded), findsOneWidget);
    });

    testWidgets('ActivityHubCard empty state renders without overflow at 320px width and 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: ActivityHubCard(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('What’s on your mind today?'), findsOneWidget);
    });

    testWidgets('ThoughtWallHomePreview empty state renders centered tranquil container without prompt chips', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(
                  compact: true,
                  previewLimit: 1,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your mindspace is clear'), findsOneWidget);
      expect(
        find.text('Capture what’s on your mind anytime.'),
        findsOneWidget,
      );
      expect(find.text('Spark idea'), findsNothing);
      expect(find.text('Daily win'), findsNothing);
      expect(find.text('Self-reflection'), findsNothing);
    });

    testWidgets('ThoughtWallHomePreview empty state renders without overflow at 320px width and 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: ThoughtWallHomePreview(
                    compact: true,
                    previewLimit: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Your mindspace is clear'), findsOneWidget);
    });

    testWidgets('ThingsHubScreen empty state renders centered text, icons, and starter actions', (tester) async {
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

      expect(find.text('What’s one thing for today?'), findsOneWidget);
      expect(
        find.text('Add a task or timed focus block to get your day started.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('starter_add_task')), findsOneWidget);
      expect(find.byKey(const ValueKey('starter_add_timer')), findsOneWidget);
    });
  });
}
