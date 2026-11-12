import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/home_design.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/home_weather.dart';
import 'package:ascent/features/home/widgets/home_life_shelf.dart';
import 'package:ascent/features/reminders/reminders_screen.dart';
import 'package:ascent/shared/widgets/main_scaffold.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Timer extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

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

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(WidgetTester t, GlobalKey key, String name) => t.runAsync(
  () async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/qa/premium-home/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    for (final font in [
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ('AscentZodiacSymbols', 'assets/fonts/AscentZodiacSymbols.ttf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Complete Home, calendar and live theme switching: dark=$dark scale=$scale',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.view.resetPhysicalSize);
          final now = DateTime.now();
          final day = DateTime(now.year, now.month, now.day);
          SharedPreferences.setMockInitialValues({
            'ascent_theme_mode': dark ? 'dark' : 'light',
            'weather_city': 'New Delhi, India',
            'ascent_daily_briefing_auto_open_v1': false,
            'ascent_first_home_day_v1': day.toIso8601String(),
            'ascent_day_one_tutorial_v2_dismissed': true,
          });
          final prefs = await SharedPreferences.getInstance();
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          final taskId = await db.taskDao.insertTask(
            TaskTableCompanion.insert(
              title: 'Make room for focused work',
              plannedDate: Value(day),
            ),
          );
          await db.reminderDao.insertReminder(
            ReminderTableCompanion.insert(
              title: 'A little time to reflect',
              scheduledAt: day.add(const Duration(days: 1, hours: 19)),
            ),
          );
          await db.waterDao.addWater(750);
          await db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(
              content: 'Make things that feel like you.',
            ),
          );
          final profile = UserProfile(
            id: 1,
            name: 'Arun Singh',
            targetRole: 'Software Engineer',
            targetCompanies: '["Google"]',
            weeklyHoursAvailable: 10,
            preferredStudyWindow: 'morning',
            skillSelfRatings: '{}',
            createdAt: day,
            updatedAt: day,
            onboardingComplete: true,
            dateOfBirth: DateTime(1998, 6, 10),
          );
          final container = ProviderContainer(
            overrides: [
              homeWeatherProvider.overrideWith(
                (ref) async => {
                  'current': {
                    'temperature_2m': 24,
                    'weather_code': 2,
                    'apparent_temperature': 24,
                    'relative_humidity_2m': 48,
                    'wind_speed_10m': 8,
                    'time': '2026-11-12T09:00',
                  },
                  'daily': {
                    'time': ['2026-11-12', '2026-11-13', '2026-11-14'],
                    'temperature_2m_min': [18, 17, 18],
                    'temperature_2m_max': [28, 27, 28],
                    'precipitation_probability_max': [5, 10, 5],
                  },
                },
              ),
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              userProfileStreamProvider.overrideWith(
                (ref) => Stream.value(profile),
              ),
              timeTrackingProvider.overrideWith(_Timer.new),
              studyStreakProvider.overrideWith(_Streak.new),
              currentStreakStreamProvider.overrideWith(
                (ref) => Stream.value(3),
              ),
              dailyWaterGoalStreamProvider.overrideWith(
                (ref) => Stream.value(2000),
              ),
              todayActivitiesProvider.overrideWith(
                (ref) => Stream.value([
                  TodayActivityItem(
                    id: 'task_$taskId',
                    title: 'Make room for focused work',
                    sourceType: 'task',
                    categoryTag: 'Personal',
                    status: TodayActivityStatus.notStarted,
                    elapsedSecondsToday: 0,
                    linkedTaskId: taskId,
                    plannedDate: day,
                    createdAt: now,
                  ),
                ]),
              ),
            ],
          );
          final router = GoRouter(
            initialLocation: '/home',
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, state) => RemindersScreen(
                  calendarOnly: true,
                  openCalendar: true,
                  initialCalendarDate: DateTime.tryParse(
                    state.uri.queryParameters['date'] ?? '',
                  ),
                ),
              ),
              StatefulShellRoute.indexedStack(
                builder: (_, _, shell) => MainScaffold(shell: shell),
                branches: [
                  for (final route in ['home', 'reminders', 'vault', 'more'])
                    StatefulShellBranch(
                      routes: [
                        GoRoute(
                          path: '/$route',
                          builder: (_, _) => route == 'home'
                              ? const HomeScreen()
                              : Scaffold(body: Text('$route destination')),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          );
          addTearDown(() async {
            router.dispose();
            container.dispose();
            await db.close();
          });
          final key = GlobalKey();
          await t.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: Consumer(
                builder: (context, ref, _) => RepaintBoundary(
                  key: key,
                  child: MaterialApp.router(
                    debugShowCheckedModeBanner: false,
                    theme: AscentTheme.light(),
                    darkTheme: AscentTheme.dark(),
                    themeMode: ref.watch(themeModeProvider),
                    routerConfig: router,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                  ),
                ),
              ),
            ),
          );
          await _settle(t);
          final prefix =
              '${dark ? 'night' : 'day'}-${scale == 1 ? 'mobile' : 'large-text'}';
          expect(t.takeException(), isNull);
          await _capture(t, key, '$prefix-top');
          if (scale == 1) {
            await t.tap(find.byKey(const ValueKey('home_weather')));
            await _settle(t);
            expect(find.text('New Delhi, India'), findsOneWidget);
            expect(find.text('Partly cloudy'), findsOneWidget);
            await _capture(t, key, '$prefix-weather');
            Navigator.of(t.element(find.text('Weather'))).pop();
            await _settle(t);
            await t.tap(find.byKey(const ValueKey('home_calendar_open')));
            await _settle(t);
            expect(
              find.byKey(const ValueKey('reminders_calendar_card')),
              findsOneWidget,
            );
            expect(find.text('Make room for focused work'), findsOneWidget);
            await _capture(t, key, '$prefix-calendar');
            await t.tap(find.byKey(const ValueKey('calendar_schedule_event')));
            await _settle(t);
            expect(find.text('Make time for it'), findsOneWidget);
            final extraDate = DateTime(
              day.year,
              day.month,
              day.day == 1 ? 2 : 1,
            );
            await t.tap(
              find.byKey(
                ValueKey(
                  'event_date_${extraDate.year}_${extraDate.month}_${extraDate.day}',
                ),
              ),
            );
            await _settle(t);
            expect(find.text('2 dates selected'), findsOneWidget);
            await _capture(t, key, '$prefix-event');
            Navigator.of(t.element(find.text('Make time for it'))).pop();
            await _settle(t);
            router.pop();
            await _settle(t);
            await t.tap(find.byKey(const ValueKey('home_day_night_toggle')));
            await _settle(t);
            expect(
              HomeDesign.of(
                t.element(find.byKey(const ValueKey('home_user_name'))),
              ).darkness,
              dark ? 0 : 1,
            );
            await t.tap(find.byKey(const ValueKey('home_day_night_toggle')));
            await _settle(t);
          }
          await t.drag(
            find.byKey(const ValueKey('home_scroll')),
            const Offset(0, -400),
          );
          await _settle(t);
          await _capture(t, key, '$prefix-middle');
          await t.scrollUntilVisible(
            find.byType(HomeLifeShelf),
            240,
            scrollable: find.byType(Scrollable).first,
          );
          await Scrollable.ensureVisible(
            t.element(find.byType(HomeLifeShelf)),
            alignment: .12,
          );
          await _settle(t);
          await _capture(t, key, '$prefix-wellbeing');
          expect(t.takeException(), isNull);
          expect(
            (await t.runAsync(() => db.select(db.taskTable).get()))!.length,
            1,
          );
          expect(
            (await t.runAsync(() => db.select(db.reminderTable).get()))!.length,
            1,
          );
          expect(
            await t.runAsync(() => db.waterDao.watchTodayWaterMl().first),
            750,
          );
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
