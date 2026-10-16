import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/ai/riya_alert_effects.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_schedule_sheet.dart';
import 'package:ascent/features/home/widgets/home_up_next.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        homeScheduleEffectsProvider.overrideWith(
          (ref) => RiyaAlertEffects(
            db,
            cancel: (_) async => true,
            schedule: (_) async => false,
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> mount(
    WidgetTester tester, {
    required ThemeData theme,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [ThoughtWallHomePreview(), HomeUpNext()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ordinary capture stays a thought and persistent Plan survives time',
    (tester) async {
      await mount(tester, theme: AscentTheme.light());
      await tester.enterText(
        find.byType(TextField),
        'A quiet thought about tomorrow',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send capture'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(await db.select(db.thoughtTable).get(), hasLength(1));
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.reminderTable).get(), isEmpty);
      await tester.pump(const Duration(seconds: 9));
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Ask Riya'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'send, review, approve produces one linked plan and exposes check-in controls',
    (tester) async {
      await mount(
        tester,
        theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
      );
      await tester.enterText(
        find.byType(TextField),
        'Tomorrow at 7 pm practise interviews for 30 minutes. Remind me and ask afterwards.',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send capture'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Make a plan'), findsOneWidget);
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(prefs.containsKey(homePendingScheduleKey), isTrue);
      final schedule = find.widgetWithText(FilledButton, 'Schedule');
      await tester.ensureVisible(schedule);
      await tester.tap(schedule);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(await db.select(db.taskTable).get(), hasLength(1));
      final reminders = await db.select(db.reminderTable).get();
      expect(reminders, hasLength(2));
      expect(reminders.first.linkedTaskId, reminders.last.linkedTaskId);
      expect(prefs.containsKey(homePendingScheduleKey), isFalse);
      expect(find.text('Up next'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Keep as thought clears the unscheduled draft without deleting the note',
    (tester) async {
      await mount(
        tester,
        theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
      );
      await tester.enterText(find.byType(TextField), 'Remind me to call Mum');
      await tester.pump();
      await tester.tap(find.byTooltip('Send capture'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(HomeScheduleSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Unscheduled plan'), findsOneWidget);
      final source = (await db.select(db.thoughtTable).get()).single;
      expect(
        find.ancestor(
          of: find.text('Review & schedule'),
          matching: find.byKey(ValueKey('home_thought_${source.id}')),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Keep as thought'));
      await tester.tap(find.text('Keep as thought'));
      await tester.pumpAndSettle();
      expect(find.text('Unscheduled plan'), findsNothing);
      expect(prefs.containsKey(homePendingScheduleKey), isFalse);
      expect(await db.select(db.thoughtTable).get(), hasLength(1));
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.reminderTable).get(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final themeName in ['clay', 'nordic', 'dark']) {
    testWidgets(
      'schedule sheet keeps draft and fits 360px with enlarged text: $themeName',
      (tester) async {
        final theme = themeName == 'dark'
            ? AscentTheme.dark()
            : AscentTheme.light(
                preset: themeName == 'nordic'
                    ? DayThemePreset.nordicSky
                    : DayThemePreset.classicClay,
              );
        await mount(tester, theme: theme, scale: 2);
        await tester.enterText(find.byType(TextField), 'Remind me to call Mum');
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byTooltip('Send capture'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();
        // Missing time must open an editable review, never guess a schedule.
        expect(find.text('Choose date and time'), findsOneWidget);
        expect(await db.select(db.reminderTable).get(), isEmpty);
        await tester.enterText(
          find.descendant(
            of: find.byType(HomeScheduleSheet),
            matching: find.byType(TextField),
          ),
          'Call Mum about the appointment',
        );
        await tester.pumpAndSettle();
        expect(
          prefs.getString(homePendingScheduleKey),
          contains('Call Mum about the appointment'),
        );
        expect(tester.takeException(), isNull);
        // Dismiss and recover the same draft.
        Navigator.of(tester.element(find.byType(HomeScheduleSheet))).pop();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Review & schedule'));
        await tester.tap(find.text('Review & schedule'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(HomeScheduleSheet),
            matching: find.text('Call Mum about the appointment'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
