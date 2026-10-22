import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['ASCENT_QA_CAPTURE'] == '1') {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Medicine & Health': true,
    });
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        medicineServiceProvider.overrideWithValue(
          MedicineService(db, syncAlerts: false),
        ),
      ],
    );
  });
  tearDown(() async => db.close());

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> mount(
    WidgetTester t, {
    bool dark = false,
    double scale = 1,
    double width = 390,
  }) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    addTearDown(t.view.resetViewInsets);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: const ValueKey('medicine_qa'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark
                ? AscentTheme.dark(preset: DayThemePreset.merlotLinen)
                : AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const MedicineScreen(),
          ),
        ),
      ),
    );
    await settle(t);
  }

  Future<void> cleanup(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    container.dispose();
    await t.pump(const Duration(seconds: 2));
    await t.pump();
  }

  Future<void> capture(WidgetTester t, String name) async {
    if (Platform.environment['ASCENT_QA_CAPTURE'] != '1') return;
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('medicine_qa')),
    );
    await t.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/ascent-medicine-$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  Future<void> pick(WidgetTester t, int index, TimeOfDay time) async {
    final target = find.byKey(ValueKey('medicine_time_$index'));
    await t.ensureVisible(target);
    await t.tap(target);
    await t.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(
      t
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialEntryMode,
      TimePickerEntryMode.input,
    );
    Navigator.of(t.element(find.byType(TimePickerDialog))).pop(time);
    await t.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'four exact custom medicine times save and reopen in Merlot dark=$dark',
      (t) async {
        await mount(t, dark: dark);
        try {
          await t.tap(find.byTooltip('Add Medicine'));
          await t.pumpAndSettle();
          await t.enterText(
            find.byKey(const ValueKey('medicine_name')),
            'My prescribed medicine',
          );
          await t.enterText(
            find.byKey(const ValueKey('medicine_dosage')),
            'Recorded dose',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpAndSettle();
          await t.ensureVisible(find.text('4 doses'));
          await t.tap(find.text('4 doses'));
          await t.pumpAndSettle();
          // No suggested schedule is silently selected.
          expect(find.text('Choose time'), findsNWidgets(4));
          await t.tap(find.text('Save medicine'));
          await t.pumpAndSettle();
          expect(
            find.text('Choose an exact time for every dose.'),
            findsOneWidget,
          );
          expect(
            await t.runAsync(() => db.medicineDao.watchAllMedicines().first),
            isEmpty,
          );
          for (final entry in [
            const TimeOfDay(hour: 6, minute: 23),
            const TimeOfDay(hour: 11, minute: 47),
            const TimeOfDay(hour: 17, minute: 16),
            const TimeOfDay(hour: 23, minute: 8),
          ].indexed) {
            await pick(t, entry.$1, entry.$2);
          }
          await t.ensureVisible(find.byKey(const ValueKey('medicine_time_0')));
          await t.pumpAndSettle();
          await capture(t, '${dark ? 'night' : 'day'}-times');
          await t.tap(find.text('Save medicine'));
          await settle(t);
          final medicines = await t.runAsync(
            () => db.medicineDao.watchAllMedicines().first,
          );
          expect(medicines, hasLength(1));
          final medicine = medicines!.single;
          expect(jsonDecode(medicine.scheduledTimes), [
            '06:23',
            '11:47',
            '17:16',
            '23:08',
          ]);
          expect(medicine.instructions, '');
          final logs = await t.runAsync(
            () => db.medicineDao.watchLogsForMedicine(medicine.id).first,
          );
          expect(logs, hasLength(28));
          final reminders = await t.runAsync(
            () => db.select(db.reminderTable).get(),
          );
          expect(
            reminders!
                .map((r) => '${r.scheduledAt.hour}:${r.scheduledAt.minute}')
                .toSet(),
            {'6:23', '11:47', '17:16', '23:8'},
          );
          expect(find.text('Add medicine'), findsNothing);
          await capture(t, '${dark ? 'night' : 'day'}-page');
          await t.ensureVisible(
            find.byKey(const ValueKey('medicine_view_medicines')),
          );
          await t.tap(find.byKey(const ValueKey('medicine_view_medicines')));
          await t.pumpAndSettle();
          await capture(t, '${dark ? 'night' : 'day'}-medicines');
          await t.ensureVisible(find.text('Edit schedule'));
          await t.pumpAndSettle();
          await t.tap(find.byTooltip('Edit Prescription'));
          await t.pumpAndSettle();
          expect(find.byKey(const ValueKey('medicine_time_3')), findsOneWidget);
          await t.ensureVisible(find.text('Add another time'));
          await t.tap(find.text('Add another time'));
          await t.pumpAndSettle();
          expect(find.byKey(const ValueKey('medicine_time_4')), findsOneWidget);
          await pick(t, 4, const TimeOfDay(hour: 6, minute: 23));
          expect(
            find.text(
              'That time is already added. Choose a different time for this dose.',
            ),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
        } finally {
          await cleanup(t);
        }
      },
    );

    testWidgets(
      'editing three doses adds and saves a fourth at 320px and 2x dark=$dark',
      (t) async {
        await MedicineService(db, syncAlerts: false).addMedicine(
          name: 'Edit fourth dose',
          dosage: 'Recorded dose',
          scheduledTimes: ['06:23', '11:47', '17:16'],
          durationDays: 1,
          startDate: DateTime.now(),
        );
        await mount(t, dark: dark, scale: 2, width: 320);
        try {
          await t.ensureVisible(
            find.byKey(const ValueKey('medicine_view_medicines')),
          );
          await t.tap(find.byKey(const ValueKey('medicine_view_medicines')));
          await t.pumpAndSettle();
          await t.ensureVisible(find.text('Edit schedule'));
          await t.pumpAndSettle();
          await t.tap(find.byTooltip('Edit Prescription'));
          await t.pumpAndSettle();
          await t.ensureVisible(find.text('4 doses'));
          await t.tap(find.text('4 doses'));
          await t.pumpAndSettle();
          await pick(t, 3, const TimeOfDay(hour: 23, minute: 8));
          await t.tap(find.text('Update Prescription'));
          await settle(t);
          final rows = await t.runAsync(
            () => db.medicineDao.watchAllMedicines().first,
          );
          expect(jsonDecode(rows!.single.scheduledTimes), [
            '06:23',
            '11:47',
            '17:16',
            '23:08',
          ]);
          expect(t.takeException(), isNull);
        } finally {
          await cleanup(t);
        }
      },
    );

    testWidgets(
      'Medicine headings and fields stay visible with keyboard at 320px and 2x text dark=$dark',
      (t) async {
        await MedicineService(db, syncAlerts: false).addMedicine(
          name:
              'A long medicine name that remains readable on the daily schedule',
          dosage: 'User recorded dose',
          scheduledTimes: ['06:23', '11:47', '17:16', '23:08'],
          durationDays: 7,
          startDate: DateTime.now(),
        );
        await mount(t, dark: dark, scale: 2, width: 320);
        await t.ensureVisible(
          find
              .text(
                'A long medicine name that remains readable on the daily schedule',
              )
              .first,
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await capture(t, '${dark ? 'night' : 'day'}-large-page');
        try {
          await t.tap(find.byTooltip('Add Medicine'));
          await t.pumpAndSettle();
          t.view.viewInsets = const FakeViewPadding(bottom: 270);
          await t.pumpAndSettle();
          await t.enterText(
            find.byKey(const ValueKey('medicine_name')),
            'A longer medicine name typed by the user',
          );
          await t.pumpAndSettle();
          expect(find.text('Medicine name'), findsOneWidget);
          final label = t.getRect(find.text('Medicine name'));
          final field = t.getRect(find.byKey(const ValueKey('medicine_name')));
          expect(label.bottom, lessThan(field.top));
          expect(find.text('Save medicine').hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull);
          await capture(t, '${dark ? 'night' : 'day'}-keyboard');
        } finally {
          await cleanup(t);
        }
      },
    );
  }
}
