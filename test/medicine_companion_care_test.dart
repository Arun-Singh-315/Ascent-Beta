import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
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

  group('Medicine Care Companion Tests', () {
    test(
      'snoozeDose updates linked reminder time and queues alert sync',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final fakeNow = DateTime(2026, 11, 15, 8, 0);
        final service = MedicineService(
          db,
          syncAlerts: false,
          clock: () => fakeNow,
        );

        final medId = await service.addMedicine(
          name: 'Omega 3',
          dosage: '1 Capsule',
          scheduledTimes: ['08:00'],
          durationDays: 5,
          startDate: DateTime(2026, 11, 15),
        );

        final logs = await db.medicineDao.watchLogsForMedicine(medId).first;
        expect(logs.isNotEmpty, isTrue);
        final firstLog = logs.first;
        expect(firstLog.linkedReminderId, isNotNull);

        final originalReminder = await db.reminderDao.getReminderById(
          firstLog.linkedReminderId!,
        );
        expect(originalReminder, isNotNull);
        expect(originalReminder!.scheduledAt, DateTime(2026, 11, 15, 8, 0));

        // Snooze by 30 minutes
        await service.snoozeDose(
          firstLog.id,
          duration: const Duration(minutes: 30),
        );

        final updatedReminder = await db.reminderDao.getReminderById(
          firstLog.linkedReminderId!,
        );
        expect(updatedReminder!.scheduledAt, DateTime(2026, 11, 15, 8, 30));
        expect(updatedReminder.alertSyncPending, isTrue);
      },
    );

    test(
      'scheduleRefillReminder creates a timely reminder for prescription refill',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final fakeNow = DateTime(2026, 11, 15, 8, 0);
        final service = MedicineService(
          db,
          syncAlerts: false,
          clock: () => fakeNow,
        );

        final medId = await service.addMedicine(
          name: 'Vitamin D3',
          dosage: '1 Tablet',
          scheduledTimes: ['09:00'],
          durationDays: 5,
          startDate: DateTime(2026, 11, 15),
        );

        final medicine = (await db.medicineDao.getMedicineById(medId))!;
        final remId = await service.scheduleRefillReminder(medicine);

        final reminder = await db.reminderDao.getReminderById(remId);
        expect(reminder, isNotNull);
        expect(
          reminder!.title.contains('Refill prescription: Vitamin D3'),
          isTrue,
        );
        expect(reminder.alertSyncPending, isTrue);
      },
    );

    testWidgets(
      'Medicine Care Companion UI renders empathetic pulse and is overflow immune at 320px & 2x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({
          'feature_guide_v1_Medicine & Health': true,
        });
        final prefs = await SharedPreferences.getInstance();

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        final now = DateTime.now();
        final service = MedicineService(db, syncAlerts: false);

        // Add a medicine whose dose is scheduled for today
        final currentTimeStr = DateFormat('HH:mm').format(now);
        await service.addMedicine(
          name: 'Amoxicillin 500mg',
          dosage: '1 Capsule',
          scheduledTimes: [currentTimeStr],
          durationDays: 3,
          startDate: DateTime(now.year, now.month, now.day),
          instructions: 'With full glass of water',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              medicineServiceProvider.overrideWithValue(service),
              sharedPreferencesProvider.overrideWithValue(prefs),
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
        expect(tester.takeException(), isNull);

        // Verify Care Companion elements appear
        expect(find.textContaining('Amoxicillin 500mg'), findsWidgets);
        expect(find.byType(MedicineScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}
