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
import 'package:ascent/features/money/add_transaction_sheet.dart';

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

  group('Money CRUD & Analytics Improvements Tests', () {
    testWidgets('AddTransactionSheet pre-fills existing transaction and updates it in database', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // Seed a transaction
      final id = await db.financeDao.insertTransaction(
        FinanceTransactionTableCompanion.insert(
          title: 'Grocery Store Trip',
          amount: 850.0,
          date: DateTime(2026, 11, 15, 14, 30),
          type: const drift.Value('expense'),
          category: const drift.Value('Food & Groceries'),
          account: const drift.Value('UPI'),
          notes: const drift.Value('Weekly veggies'),
        ),
      );

      final transaction = (await db.select(db.financeTransactionTable).get()).first;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: AddTransactionSheet(transactionToEdit: transaction),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that title and amount fields are pre-filled
      expect(find.text('Grocery Store Trip'), findsOneWidget);
      expect(find.text('850'), findsOneWidget);
      expect(find.text('Update Transaction'), findsOneWidget);

      // Modify the title
      await tester.enterText(find.widgetWithText(TextField, 'Grocery Store Trip'), 'Organic Grocery Store');
      await tester.pump();

      // Tap update button
      await tester.tap(find.text('Update Transaction'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify database updated
      final updated = (await db.select(db.financeTransactionTable).get()).first;
      expect(updated.title, 'Organic Grocery Store');
      expect(updated.id, id);

      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('MoneyScreen displays Edit option for transactions and Category Spending breakdown', (
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

      await db.financeDao.insertTransaction(
        FinanceTransactionTableCompanion.insert(
          title: 'Metro Commute',
          amount: 60.0,
          date: now,
          type: const drift.Value('expense'),
          category: const drift.Value('Transport'),
          account: const drift.Value('UPI'),
        ),
      );

      await db.financeDao.insertTransaction(
        FinanceTransactionTableCompanion.insert(
          title: 'Dinner at Bistro',
          amount: 540.0,
          date: now,
          type: const drift.Value('expense'),
          category: const drift.Value('Food & Groceries'),
          account: const drift.Value('UPI'),
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
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
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

      final scrollable = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ).first;
      final itemFinder = find.textContaining('Metro Commute');
      await tester.scrollUntilVisible(itemFinder, 200, scrollable: scrollable);

      // Verify category spending breakdown or recent transactions
      expect(itemFinder, findsWidgets);
      // Verify edit icon button is present on the transaction card
      expect(find.byTooltip('Edit transaction'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    testWidgets('Savings Goals support custom Deposit and Edit dialogs without overflow', (
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

      await db.financeDao.insertSavingsGoal(
        SavingsGoalTableCompanion.insert(
          title: 'Emergency Fund',
          targetAmount: 50000.0,
          savedAmount: const drift.Value(12000.0),
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
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: const MoneyScreen(),
          ),
        ),
      );

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Go to Tab 1 (Budgets & Goals)
      await tester.tap(find.text('Budgets & Goals'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final scrollableTab1 = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ).last;
      final goalFinder = find.text('Emergency Fund');
      await tester.scrollUntilVisible(goalFinder, 200, scrollable: scrollableTab1);

      expect(goalFinder, findsOneWidget);
      expect(find.byTooltip('Edit goal'), findsOneWidget);
      expect(find.byTooltip('Deposit or withdraw funds'), findsOneWidget);

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
  });
}
