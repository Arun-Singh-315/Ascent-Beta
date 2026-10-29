import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';
import 'package:ascent/shared/widgets/glass_chip.dart';
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
        learningHubProvider.overrideWith(_IdleLearning.new),
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
    testWidgets(
      'pending and taken care groups retain undo at 320px, dark=$dark',
      (t) async {
        t.view.physicalSize = const Size(320, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        // Both actions must be due; the real clock may be before 20:00.
        await (db.update(db.medicineLogTable)).write(
          const MedicineLogTableCompanion(timeSlot: drift.Value('00:00')),
        );
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
              theme: dark
                  ? AscentTheme.dark(preset: DayThemePreset.merlotLinen)
                  : AscentTheme.light(),
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
        expect(find.byTooltip('Mark taken'), findsNWidgets(2));
        await t.ensureVisible(find.byTooltip('Mark taken').first);
        await t.tap(find.byTooltip('Mark taken').first);
        await flush();
        expect(
          (await t.runAsync(
            () => db.medicineDao.watchTodayMedicineLogs().first,
          ))!.where((l) => l.isTaken),
          hasLength(1),
        );
        await t.ensureVisible(find.widgetWithText(GlassChip, '1 taken'));
        await t.tap(find.widgetWithText(GlassChip, '1 taken'));
        await flush();
        expect(find.byTooltip('Undo taken dose'), findsOneWidget);
        await t.ensureVisible(find.byTooltip('Undo taken dose'));
        await t.tap(find.byTooltip('Undo taken dose'));
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
      },
    );
  }
}
