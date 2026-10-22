import 'package:ascent/features/plans/planning_providers.dart';
import 'package:ascent/core/notifications/reminder_alert_sync.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/plans/widgets/plan_collection_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        planningAlertSyncProvider.overrideWith(
          (ref) => ReminderAlertSync(
            db,
            enabled: () async => true,
            reset: () async => true,
            cancel: (_) async => true,
            schedule: (_) async => true,
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> mount(
    WidgetTester t, {
    double width = 390,
    double scale = 1,
    bool dailyTimes = false,
  }) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: PlanCollectionEditor(
              initialText: 'Review Java',
              dailyTimes: dailyTimes,
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> open(WidgetTester t) async {
    final target = find.text('Add time');
    for (var n = 0; n < 14 && target.hitTestable().evaluate().isEmpty; n++) {
      await t.drag(find.byType(ListView), const Offset(0, -150));
      await t.pumpAndSettle();
    }
    await t.tap(target.hitTestable().first);
    await t.pumpAndSettle();
  }

  Future<void> select(WidgetTester t, String text) async {
    final target = find.widgetWithText(ChoiceChip, text);
    await t.ensureVisible(target);
    await t.tap(target);
    await t.pumpAndSettle();
  }

  testWidgets('repeat shortcut opens the daily time choices immediately', (
    t,
  ) async {
    await mount(t, dailyTimes: true);
    expect(find.text('4 times'), findsOneWidget);
    expect(find.text('Time 4'), findsOneWidget);
    expect(find.text('Choose end date'), findsOneWidget);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'four daily times persist as four independently scheduled routines',
    (t) async {
      await mount(t);
      final repeat = find.text('Several times a day');
      await t.ensureVisible(repeat);
      await t.tap(repeat);
      await t.pumpAndSettle();
      await t.tap(find.text('Use these times'));
      await t.pumpAndSettle();
      expect(
        find.text('Choose distinct times and an end date.'),
        findsOneWidget,
      );
      for (var i = 0; i < 4; i++) {
        await t.ensureVisible(find.text('Time ${i + 1}'));
        await t.tap(find.text('Time ${i + 1}'));
        await t.pumpAndSettle();
        Navigator.of(
          t.element(find.byType(TimePickerDialog)),
        ).pop(TimeOfDay(hour: 8 + i * 4, minute: 15));
        await t.pumpAndSettle();
      }
      await t.ensureVisible(find.text('Choose end date'));
      await t.tap(find.text('Choose end date'));
      await t.pumpAndSettle();
      Navigator.of(
        t.element(find.byType(DatePickerDialog)),
      ).pop(DateTime.now().add(const Duration(days: 7)));
      await t.pumpAndSettle();
      await t.tap(find.text('Use these times'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Save plan'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await t.pumpAndSettle();
      final rows = await db.select(db.planDefinitionTable).get();
      expect(rows.length, 4);
      expect(rows.every((row) => row.recurrenceRule == 'daily'), isTrue);
      final reminders = await db.select(db.reminderTable).get();
      expect(reminders.map((r) => r.scheduledAt.hour).toSet(), {8, 12, 16, 20});
      expect(reminders.every((r) => r.scheduledAt.minute == 15), isTrue);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reminder immediately requests its date and cancel leaves it off',
    (t) async {
      await mount(t);
      await open(t);
      await select(t, 'Reminder');
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('Reminder date'), findsOneWidget);
      await t.tap(find.text('Cancel').last);
      await t.pumpAndSettle();
      expect(
        t
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Silent'))
            .selected,
        isTrue,
      );
      expect(find.text('No time'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('repeat gathers start time and end date before enabling itself', (
    t,
  ) async {
    await mount(t);
    await open(t);
    await select(t, 'Every day');
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await t.tap(find.text('OK').last);
    await t.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await t.tap(find.text('OK').last);
    await t.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.text('Repeat until'), findsOneWidget);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    expect(
      t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Once')).selected,
      isTrue,
    );
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('complete repeat setup displays the full schedule before Apply', (
    t,
  ) async {
    await mount(t);
    await open(t);
    await select(t, 'Every day');
    await t.tap(find.text('OK').last);
    await t.pumpAndSettle();
    await t.tap(find.text('OK').last);
    await t.pumpAndSettle();
    await t.tap(find.text('OK').last);
    await t.pumpAndSettle();
    expect(
      t
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Every day'))
          .selected,
      isTrue,
    );
    expect(find.textContaining('Repeats daily until'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('date-only asks for a date immediately', (t) async {
    await mount(t);
    await open(t);
    await t.tap(find.widgetWithText(FilterChip, 'Date only · no alert'));
    await t.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    expect(
      t
          .widget<FilterChip>(
            find.widgetWithText(FilterChip, 'Date only · no alert'),
          )
          .selected,
      isFalse,
    );
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'plan name remains labelled and wraps with keyboard and large text',
    (t) async {
      await mount(t, width: 320, scale: 2);
      final name = find.byKey(const ValueKey('plan_name_field'));
      await t.enterText(name, 'Interview preparation and application practice');
      await t.pump();
      expect(find.text('Plan name'), findsOneWidget);
      expect(t.widget<TextField>(name).maxLines, 3);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Custom opens the required date picker immediately and cancel preserves No times',
    (t) async {
      await mount(t);
      await t.tap(find.widgetWithText(ChoiceChip, 'Custom'));
      await t.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.text('Schedule date'), findsOneWidget);
      await t.tap(find.text('Cancel').last);
      await t.pumpAndSettle();
      expect(
        t
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'No times'))
            .selected,
        isTrue,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('check-in immediately asks for a start time when none exists', (
    t,
  ) async {
    await mount(t);
    await open(t);
    final toggle = find.widgetWithText(SwitchListTile, 'Check in afterwards');
    for (var n = 0; n < 16 && toggle.hitTestable().evaluate().isEmpty; n++) {
      await t.drag(
        find.byKey(const ValueKey('item_settings_scroll')),
        const Offset(0, -150),
      );
      await t.pumpAndSettle();
    }
    await t.tap(toggle.hitTestable());
    await t.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await t.tap(find.text('Cancel').last);
    await t.pumpAndSettle();
    expect(t.widget<SwitchListTile>(toggle).value, isFalse);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('new rows inherit the selected default schedule', (t) async {
    await mount(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'Tomorrow morning'));
    await t.pumpAndSettle();
    final add = find.widgetWithText(OutlinedButton, 'Add item');
    for (var n = 0; n < 14 && add.hitTestable().evaluate().isEmpty; n++) {
      await t.drag(find.byType(ListView), const Offset(0, -150));
      await t.pumpAndSettle();
    }
    await t.tap(add.hitTestable());
    await t.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(PlanCollectionEditor),
      matching: find.byType(TextField),
    );
    final second = t
        .widgetList<TextField>(fields)
        .where((f) => f.decoration?.hintText == 'What needs doing?')
        .last;
    second.controller!.text = 'Practise RAG';
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Save plan'));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
    final reminders = await db.select(db.reminderTable).get();
    expect(reminders.length, 2);
    expect(
      reminders.last.scheduledAt
          .difference(reminders.first.scheduledAt)
          .inMinutes,
      30,
    );
    await t.pumpWidget(const SizedBox());
  });
}
