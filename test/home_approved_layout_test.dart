import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/core/services/festival_service.dart';
import 'package:ascent/features/home/widgets/home_shortcut_icon.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Streak extends StudyStreakNotifier {
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
  late ProviderContainer container;
  setUpAll(() async {
    await (FontLoader(
      'AscentZodiacSymbols',
    )..addFont(rootBundle.load('assets/fonts/AscentZodiacSymbols.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        todayFestivalProvider.overrideWithValue(null),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        studyStreakProvider.overrideWith(() => _Streak()),
        currentStreakStreamProvider.overrideWith((ref) => Stream.value(14)),
        homeStreakVisibleProvider.overrideWithValue(true),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }

  testWidgets(
    'Shortcut tiles stay neutral and reminder opens its actual destination',
    (tester) async {
      final reminder = Reminder(
        id: 73,
        title: 'Evening supplements',
        scheduledAt: DateTime.now().add(const Duration(hours: 3)),
        alarmEnabled: false,
        alertSyncPending: false,
        isActive: true,
        createdAt: DateTime.now(),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: HomeShortcutPanel(
                  showReminders: true,
                  reminders: [reminder],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/reminders',
            builder: (_, state) => Scaffold(
              body: Text('Opened ${state.uri.queryParameters['reminder']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: HomeTheme.from(AscentTheme.light()),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(HomeShortcutIcon), findsNWidgets(4));
      for (final icon in find.byType(HomeShortcutIcon).evaluate()) {
        final box = find.descendant(
          of: find.byWidget(icon.widget),
          matching: find.byType(Container),
        );
        final decoration =
            tester.widget<Container>(box).decoration! as BoxDecoration;
        expect(decoration.color, isNot(Colors.transparent));
        expect(decoration.border, isNotNull);
      }
      expect(find.text('Evening supplements'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hub_reminder_73')));
      await settle(tester);
      expect(find.text('Opened 73'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
