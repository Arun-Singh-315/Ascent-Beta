import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';
import 'package:ascent/features/money/money_screen.dart';
import 'package:ascent/features/reminders/reminders_screen.dart';
import 'package:ascent/shared/widgets/ascent_card.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      for (final feature in ['Medicines', 'Reminders', 'Money']) {
        testWidgets('$feature grouped rows fit 320px, scale $scale, dark $dark', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            'feature_guide_v1_Money & Budgets': true,
            'feature_guide_v1_Reminders & Alerts': true,
          });
          final prefs = await SharedPreferences.getInstance();
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          final now = DateTime.now();
          final day = DateTime(now.year, now.month, now.day);
          if (feature == 'Medicines') {
            for (var i = 0; i < 2; i++) {
              final id = await db.medicineDao.insertMedicine(
                MedicineTableCompanion.insert(
                  name: 'Long medicine name with a detailed prescription $i',
                  dosage: 'One tablet with food',
                  scheduledTimes: '["23:59"]',
                  durationDays: const drift.Value(7),
                  startDate: day,
                ),
              );
              await db.medicineDao.insertMedicineLog(
                MedicineLogTableCompanion.insert(
                  medicineId: id,
                  dateStr:
                      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                  timeSlot: '23:59',
                ),
              );
            }
          } else if (feature == 'Reminders') {
            for (var i = 0; i < 2; i++) {
              await db.reminderDao.insertReminder(
                ReminderTableCompanion.insert(
                  title:
                      'Long overdue reminder title that should wrap across lines $i',
                  scheduledAt: day.subtract(const Duration(days: 1)),
                  alarmEnabled: const drift.Value(true),
                ),
              );
            }
          } else {
            for (var i = 0; i < 2; i++) {
              await db.financeDao.insertTransaction(
                FinanceTransactionTableCompanion.insert(
                  title: 'Long transaction title for a monthly subscription $i',
                  amount: 12345678,
                  date: day,
                  category: const drift.Value('Bills & Subscriptions'),
                  account: const drift.Value('Credit Card'),
                  type: drift.Value(i == 0 ? 'income' : 'expense'),
                ),
              );
            }
          }
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                sharedPreferencesProvider.overrideWithValue(prefs),
                medicineServiceProvider.overrideWithValue(
                  MedicineService(db, syncAlerts: false),
                ),
              ],
              child: MaterialApp(
                theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: switch (feature) {
                  'Medicines' => const MedicineScreen(),
                  'Reminders' => const RemindersScreen(),
                  _ => const MoneyScreen(),
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (feature == 'Medicines') {
            expect(find.text('2 pending'), findsOneWidget);
            final cards = find.ancestor(
              of: find.text('Your daily care'),
              matching: find.byType(GlassSurface),
            );
            expect(cards, findsOneWidget);
            // The dose rows and summary share their outer surface.
            final card = tester.widget<GlassSurface>(cards);
            expect(
              find.descendant(
                of: find.byWidget(card),
                matching: find.byKey(const ValueKey('medicine_dose_1')),
              ),
              findsOneWidget,
            );
            await tester.tap(
              find.byKey(const ValueKey('medicine_view_medicines')),
            );
            await tester.pumpAndSettle();
          } else if (feature == 'Reminders') {
            expect(find.text('Active (2)'), findsOneWidget);
            final rows = find.byType(Dismissible);
            expect(rows, findsNWidgets(2));
            final firstGroup = tester.widget<AscentCard>(
              find
                  .ancestor(of: rows.first, matching: find.byType(AscentCard))
                  .first,
            );
            final secondGroup = tester.widget<AscentCard>(
              find
                  .ancestor(of: rows.last, matching: find.byType(AscentCard))
                  .first,
            );
            expect(identical(firstGroup, secondGroup), isTrue);
            // The unsupported direction must not alter the record.
            await tester.ensureVisible(rows.first);
            await tester.drag(rows.first, const Offset(180, 0));
            await tester.pumpAndSettle();
            expect(await db.reminderDao.getReminderById(1), isNotNull);
            // The existing delete gesture retains its Undo action.
            await tester.drag(rows.first, const Offset(-280, 0));
            await tester.pumpAndSettle();
            for (var i = 0; i < 5; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(
              await tester.runAsync(() => db.reminderDao.getReminderById(1)),
              isNull,
            );
            expect(find.text('Reminder deleted'), findsOneWidget);
            await tester.tap(find.text('UNDO'));
            for (var i = 0; i < 5; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump(const Duration(milliseconds: 100));
            }
            expect(
              await tester.runAsync(() => db.reminderDao.getReminderById(1)),
              isNotNull,
            );
          } else {
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('transaction_2')),
              160,
              scrollable: find
                  .byWidgetPredicate(
                    (w) =>
                        w is Scrollable &&
                        w.axisDirection == AxisDirection.down,
                  )
                  .first,
            );
            await tester.pumpAndSettle();
            final row1 = find.byKey(const ValueKey('transaction_1'));
            final row2 = find.byKey(const ValueKey('transaction_2'));
            expect(
              identical(
                tester.widget(
                  find
                      .ancestor(of: row1, matching: find.byType(AscentCard))
                      .first,
                ),
                tester.widget(
                  find
                      .ancestor(of: row2, matching: find.byType(AscentCard))
                      .first,
                ),
              ),
              isTrue,
            );
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });
      }
    }
  }
  testWidgets(
    'empty reminders explain denied notification permission at 320px with large text',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'areNotificationsEnabled' ? false : true,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Reminders & Alerts': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
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
            home: const RemindersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Notifications disabled'), findsOneWidget);
      expect(find.text('Enable notifications'), findsOneWidget);
      expect(find.text('No Reminders Yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
