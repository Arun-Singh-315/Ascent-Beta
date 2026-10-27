import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/quick_modules_nav_hub.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdleTracking extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _IdleLearning extends LearningHubNotifier {
  @override
  LearningHubState build() => const LearningHubState(
    courses: [],
    activeCourseId: '',
    activeLectureId: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Widget app(Widget child, {bool dark = false, double scale = 1}) =>
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(_IdleTracking.new),
          learningHubProvider.overrideWith(_IdleLearning.new),
        ],
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      );

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final dark in [false, true]) {
    testWidgets(
      'Header assistant replaces Start without overlap at 320px and 2x text, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(const HomeHeader(profile: null), dark: dark, scale: 2),
        );
        await tester.pumpAndSettle();
        expect(find.text('Start'), findsNothing);
        expect(find.text('Ask Riya'), findsOneWidget);
        final assistant = tester.getRect(
          find.byKey(const ValueKey('home_assistant_button')),
        );
        final date = tester.getRect(find.byKey(const ValueKey('home_date')));
        expect(assistant.overlaps(date), false);
        expect(assistant.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'Compact Mind palace shows one two-line excerpt and View all opens the full wall',
    (tester) async {
      final thoughts = <Thought>[];
      for (var i = 0; i < 3; i++) {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content:
                'Saved reflection $i with several lines of detail.\nKeep the full thought accessible.\nAnother paragraph that belongs on the full wall.',
          ),
        );
        thoughts.add((await db.thoughtDao.getThoughtById(id))!);
      }
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(previewLimit: 1, compact: true),
              ),
            ),
          ),
          GoRoute(
            path: '/thought-wall',
            builder: (_, _) => const Scaffold(body: Text('Full thought wall')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value(thoughts),
            ),
          ],
          child: MaterialApp.router(
            theme: AscentTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith(
                'home_thought_entrance_',
              ),
        ),
        findsOneWidget,
      );
      final excerpt = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.textSpan?.toPlainText().startsWith('Saved reflection') == true,
        ),
      );
      expect(excerpt.maxLines, 2);
      expect(find.text('View all'), findsOneWidget);
      await tester.tap(find.text('View all'));
      await tester.pumpAndSettle();
      expect(find.text('Full thought wall'), findsOneWidget);
      expect(
        await tester.runAsync(() => db.select(db.thoughtTable).get()),
        hasLength(3),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Done feedback survives the row disappearing and opens Completed at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final now = DateTime.now();
        final id = await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Finish a test activity',
            plannedDate: drift.Value(DateTime(now.year, now.month, now.day)),
          ),
        );
        await tester.pumpWidget(app(const ActivityHubCard(), scale: scale));
        await flush(tester);
        final done = find.widgetWithText(FilledButton, 'Done');
        expect(done, findsOneWidget);
        await tester.ensureVisible(done);
        await tester.tap(done);
        await flush(tester);
        expect(
          (await tester.runAsync(
            () => db.taskDao.getTaskById(id),
          ))!.actualCompletedDate,
          isNotNull,
        );
        expect(find.text('Task completed'), findsOneWidget);
        expect(find.text('View completed'), findsOneWidget);
        await tester.tap(find.text('View completed'));
        await flush(tester);
        expect(find.text('Finish a test activity'), findsOneWidget);
        expect(find.text('No completed activities yet'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('Empty health summary uses words and keeps hydration quick add', (
    tester,
  ) async {
    await tester.pumpWidget(app(const QuickModulesNavHub()));
    await flush(tester);
    expect(find.text('No doses scheduled'), findsOneWidget);
    expect(find.byKey(const ValueKey('medicine_progress_bar')), findsNothing);
    expect(
      find.byKey(const ValueKey('hydration_progress_bar')),
      findsOneWidget,
    );
    expect(find.text('250'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
