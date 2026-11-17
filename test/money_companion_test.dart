import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/money/money_screen.dart';

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

  group('Mindful Money Management & Safe-to-Spend Tests', () {
    testWidgets('MoneyScreen displays Safe-to-Spend Today velocity card and is overflow immune at 320px & 2x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final now = DateTime.now();

      // Seed monthly budget
      await db.into(db.financeBudgetTable).insert(
        FinanceBudgetTableCompanion.insert(
          monthlyLimit: 15000.0,
          dailyLimit: const drift.Value(500.0),
        ),
      );

      // Seed an expense today
      await db.into(db.financeTransactionTable).insert(
        FinanceTransactionTableCompanion.insert(
          title: 'Healthy Grocery Haul',
          amount: 450.0,
          type: const drift.Value('expense'),
          category: const drift.Value('Food & Groceries'),
          date: now,
          account: const drift.Value('UPI'),
          notes: const drift.Value('Essential 🍞'),
        ),
      );

      // Seed a recurring subscription bill
      await db.into(db.financeTransactionTable).insert(
        FinanceTransactionTableCompanion.insert(
          title: 'Cloud Storage & Dev Tools',
          amount: 899.0,
          type: const drift.Value('expense'),
          category: const drift.Value('Bills & Subscriptions'),
          date: now.subtract(const Duration(days: 25)),
          account: const drift.Value('Credit Card'),
          isRecurring: const drift.Value(true),
        ),
      );

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
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: const MoneyScreen(),
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tester.takeException(), isNull);

      // Verify safe-to-spend velocity elements render
      expect(find.textContaining('Safe to Spend Today'), findsOneWidget);

      final scrollable = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ).first;
      final itemFinder = find.textContaining('Healthy Grocery Haul');
      await tester.scrollUntilVisible(itemFinder, 200, scrollable: scrollable);
      expect(itemFinder, findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('Toggling Daily Expense Check-in Reminder schedules 9:00 PM reminder in database', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const MoneyScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Tab 1 (Budgets & Goals)
      await tester.tap(find.text('Budgets & Goals'));
      await tester.pumpAndSettle();

      // Find switch
      final reminderSwitch = find.byKey(const ValueKey('expense_reminder_switch'));
      await tester.scrollUntilVisible(
        reminderSwitch,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(reminderSwitch, findsOneWidget);

      // Toggle switch
      await tester.tap(reminderSwitch);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final reminders = await tester.runAsync(
        () => db.reminderDao.watchAllReminders().first,
      );
      expect(reminders!.any((r) => r.title.contains('Expense') || r.title.contains('Spend')), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
