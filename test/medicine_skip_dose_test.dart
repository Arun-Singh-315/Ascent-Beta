import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';

void main() {
  setUpAll(() async {
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
  });

  group('Medicine Skip Dose & Clinical Reason Tests', () {
    test(
      'MedicineService.skipDose silences linked reminder, records skip reason and completes task',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final service = MedicineService(db, syncAlerts: false);

        final now = DateTime.now();
        final id = await service.addMedicine(
          name: 'Metformin',
          dosage: '500 mg',
          scheduledTimes: ['08:00', '20:00'],
          durationDays: 5,
          startDate: now,
        );

        final logs = await db.medicineDao.watchLogsForMedicine(id).first;
        expect(logs.isNotEmpty, isTrue);

        final firstLog = logs.first;
        expect(firstLog.isTaken, isFalse);

        // Skip dose with clinical reason
        await service.skipDose(firstLog.id, reason: 'Fasting for blood test');

        final updatedLogs = await db.medicineDao.watchLogsForMedicine(id).first;
        final updatedFirstLog = updatedLogs.firstWhere(
          (l) => l.id == firstLog.id,
        );
        expect(updatedFirstLog.isTaken, isTrue);

        // Check linked reminder silenced
        if (updatedFirstLog.linkedReminderId != null) {
          final reminder = await db.reminderDao.getReminderById(
            updatedFirstLog.linkedReminderId!,
          );
          expect(reminder?.isActive, isFalse);
        }

        // Check linked task has note
        if (updatedFirstLog.linkedTaskId != null) {
          final task = await db.taskDao.getTaskById(
            updatedFirstLog.linkedTaskId!,
          );
          expect(
            task?.notes?.contains('Skipped: Fasting for blood test'),
            isTrue,
          );
          expect(task?.actualCompletedDate, isNotNull);
        }
      },
    );

    testWidgets(
      'MedicineScreen renders Skip action on overdue doses and is overflow immune at 320px & 2.0x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final service = MedicineService(db, syncAlerts: false);
        final now = DateTime.now();

        await service.addMedicine(
          name: 'Paracetamol',
          dosage: '650 mg',
          scheduledTimes: ['00:01'], // Past midnight, always overdue during day
          durationDays: 3,
          startDate: now,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              medicineServiceProvider.overrideWithValue(service),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2.0)),
                child: child!,
              ),
              home: const MedicineScreen(),
            ),
          ),
        );

        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Overdue doses keep Snooze and Skip in one small menu.
        expect(find.textContaining('Paracetamol'), findsWidgets);
        expect(tester.takeException(), isNull);
        final more = find.byTooltip('Snooze or skip');
        expect(more, findsWidgets);
        await tester.dragUntilVisible(
          more.first,
          find.byKey(const ValueKey(false)),
          const Offset(0, -200),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(more.first);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Skip this dose'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tapAt(const Offset(4, 4));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        await tester.pumpWidget(const SizedBox());
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
    );
  });
}
