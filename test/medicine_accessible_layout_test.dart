import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';

void main() {
  testWidgets('Medicine schedules and edit sheet fit 320px with large text', (
    tester,
  ) async {
    final handler = FlutterError.onError;
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details, forceReport: true);
      handler?.call(details);
    };
    addTearDown(() => FlutterError.onError = handler);
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Medicine & Health': true,
    });
    final prefs = await SharedPreferences.getInstance();
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ]) {
      GoogleFonts.plusJakartaSans(fontWeight: weight);
      GoogleFonts.jetBrainsMono(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    await MedicineService(db, syncAlerts: false).addMedicine(
      name: 'A long user supplied medicine schedule name',
      dosage: 'User recorded dose',
      scheduledTimes: ['08:00'],
      durationDays: 7,
      startDate: DateTime(now.year, now.month, now.day + 1),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          medicineServiceProvider.overrideWithValue(
            MedicineService(db, syncAlerts: false),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
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
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('Edit Prescription'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byTooltip('Edit Prescription'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Update Prescription'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first, 'Renamed schedule');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(find.text('Update Prescription'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Update Prescription'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final medicines = await tester.runAsync(
      () => db.medicineDao.watchAllMedicines().first,
    );
    expect(medicines, hasLength(1));
    expect(medicines!.single.name, 'Renamed schedule');
    expect(find.text('Update Prescription'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
