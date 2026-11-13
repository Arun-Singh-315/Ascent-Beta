import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/features/calendar/calendar_event_sheet.dart';
import 'package:ascent/features/home/widgets/home_weather.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  test(
    'Multi-date appointments deduplicate dates and preserve existing records',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Original',
          scheduledAt: DateTime(2030),
        ),
      );
      final ids = await saveCalendarAppointments(
        db,
        title: 'Design review',
        dates: [
          DateTime(2030, 2, 3),
          DateTime(2030, 2, 3, 12),
          DateTime(2030, 3, 8),
        ],
        time: const TimeOfDay(hour: 14, minute: 30),
        meeting: true,
        notify: true,
      );
      expect(ids.length, 2);
      final rows = await db.select(db.reminderTable).get();
      expect(rows.first.title, 'Original');
      expect(
        rows
            .skip(1)
            .every(
              (r) =>
                  r.title == 'Meeting · Design review' &&
                  r.scheduledAt.hour == 14 &&
                  r.scheduledAt.minute == 30 &&
                  r.alertSyncPending,
            ),
        isTrue,
      );
      await expectLater(
        saveCalendarAppointments(
          db,
          title: '',
          dates: [DateTime(2030)],
          time: const TimeOfDay(hour: 9, minute: 0),
          meeting: false,
          notify: false,
        ),
        throwsArgumentError,
      );
      expect((await db.select(db.reminderTable).get()).length, 3);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets('Event sheet multiple-date selection fits at scale $scale', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await t.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: HomeTheme.from(AscentTheme.light()),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: CalendarEventSheet(initialDate: DateTime(2030, 2, 3)),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      final day = find.byKey(const ValueKey('event_date_2030_2_5'));
      await t.ensureVisible(day);
      await t.tap(day);
      await t.pumpAndSettle();
      expect(find.text('2 dates selected'), findsOneWidget);
      await t.tap(day);
      await t.pumpAndSettle();
      expect(find.text('1 date selected'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(await db.select(db.reminderTable).get(), isEmpty);
    });
  }
  testWidgets('Weather setup and offline details remain usable', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          homeWeatherProvider.overrideWith(
            (ref) async => throw Exception('offline'),
          ),
        ],
        child: MaterialApp(
          theme: HomeTheme.from(AscentTheme.light()),
          home: const Scaffold(body: HomeWeather()),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Weather unavailable · Retry'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('home_weather')));
    await t.pumpAndSettle();
    expect(
      find.text('Weather could not load. Check your connection and retry.'),
      findsOneWidget,
    );
    expect(find.text('Choose your city'), findsOneWidget);
    expect(t.takeException(), isNull);
    expect(prefs.getDouble('weather_lat'), isNull);
  });
  test('Weather conditions distinguish snow, fog and storms', () {
    expect(weatherDescription(0), 'Clear sky');
    expect(weatherDescription(45), 'Fog');
    expect(weatherDescription(73), 'Snow');
    expect(weatherDescription(96), 'Thunderstorms');
  });
}
