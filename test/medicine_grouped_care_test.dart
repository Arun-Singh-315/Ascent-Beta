import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdleTracking extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  late MedicineService medicine;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    medicine = MedicineService(db, syncAlerts: false);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        medicineServiceProvider.overrideWithValue(medicine),
        timeTrackingProvider.overrideWith(_IdleTracking.new),
      ],
    );
    await medicine.addMedicine(
      name: 'Recorded medicine',
      dosage: 'Recorded dose',
      scheduledTimes: ['08:00', '20:00'],
      durationDays: 1,
      startDate: DateTime.now(),
      instructions: 'Recorded instructions',
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets(
    'dose tasks retain identity and project into the medicine category',
    (t) async {
      await t.runAsync(
        () => db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Ordinary to-do',
            plannedDate: drift.Value(DateTime.now()),
          ),
        ),
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                final items = ref.watch(todayActivitiesProvider).value ?? [];
                return Text('${items.length} activities');
              },
            ),
          ),
        ),
      );
      Future<void> flush() async {
        for (var i = 0; i < 8; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump(const Duration(milliseconds: 100));
        }
      }

      await flush();
      final items = container.read(todayActivitiesProvider).requireValue;
      final doses = items.where((a) => a.sourceType == 'medicine').toList();
      expect(doses, hasLength(2));
      expect(doses.map((a) => a.plannedDate!.hour), [8, 20]);
      expect(items.where((a) => a.sourceType == 'task'), hasLength(1));
      final log = (await t.runAsync(
        () => db.medicineDao.watchTodayMedicineLogs().first,
      ))!.first;
      await t.runAsync(() => medicine.toggleDose(log.id, true));
      await flush();
      final updated = container.read(todayActivitiesProvider).requireValue;
      expect(updated.where((a) => a.sourceType == 'medicine'), hasLength(2));
      expect(
        updated.singleWhere((a) => a.linkedTaskId == log.linkedTaskId).status,
        TodayActivityStatus.done,
      );
      expect(
        await t.runAsync(() => db.select(db.taskTable).get()),
        hasLength(3),
      );
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(milliseconds: 100));
    },
  );
  for (final dark in [false, true]) {
    testWidgets('dose checks take and undo at 320px, dark=$dark', (t) async {
      t.view.physicalSize = const Size(320, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      // Both actions must be due; the real clock may be before 20:00.
      await (db.update(
        db.medicineLogTable,
      )).write(const MedicineLogTableCompanion(timeSlot: drift.Value('00:00')));
      Future<void> flush() async {
        for (var i = 0; i < 6; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump(const Duration(milliseconds: 100));
        }
      }

      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: dark ? AscentTheme.dark() : AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const MedicineScreen(),
          ),
        ),
      );
      await flush();
      // Each dose row has a round check: tap to take, tap again to undo.
      final checks = find.byWidgetPredicate(
        (w) => '${w.key}'.contains('medicine_dose_check_'),
      );
      expect(checks, findsNWidgets(2));
      await t.ensureVisible(checks.first);
      await t.pumpAndSettle();
      await t.tap(checks.first);
      await flush();
      expect(
        (await t.runAsync(
          () => db.medicineDao.watchTodayMedicineLogs().first,
        ))!.where((l) => l.isTaken),
        hasLength(1),
      );
      expect(find.bySemanticsLabel(RegExp(r'taken, undo$')), findsOneWidget);
      final taken = find.byWidgetPredicate(
        (w) => '${w.key}'.contains('medicine_dose_check_'),
      );
      await t.ensureVisible(taken.first);
      await t.pumpAndSettle();
      await t.tap(taken.first);
      await flush();
      expect(
        (await t.runAsync(
          () => db.medicineDao.watchTodayMedicineLogs().first,
        ))!.every((l) => !l.isTaken),
        isTrue,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    });
  }
}
