import 'dart:convert';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_quick_add_sheet.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('doses group by part of day', () {
    expect(partOfDay('06:30'), 'Morning');
    expect(partOfDay('13:00'), 'Afternoon');
    expect(partOfDay('18:15'), 'Evening');
    expect(partOfDay('22:00'), 'Night');
    expect(partOfDay('02:00'), 'Night');
  });

  Future<AppDatabase> pump(WidgetTester tester, {double scale = 1}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(body: MedicineQuickAddSheet()),
        ),
      ),
    );
    return db;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('type a prescription line and add it in one tap', (tester) async {
    final db = await pump(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('medicine_quick_text')),
        matching: find.byType(EditableText),
      ),
      'Dolo 650 twice a day after food for 5 days',
    );
    await tester.pump();
    expect(
      find.text(
        'Usual timing for Dolo 650 filled in. Follow your doctor’s prescription and change anything here.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('medicine_quick_save')),
    );
    await tester.tap(find.byKey(const ValueKey('medicine_quick_save')));
    await settle(tester);

    final meds = await tester.runAsync(() => db.select(db.medicineTable).get());
    final m = meds!.single;
    expect(m.name, 'Dolo 650');
    expect(m.dosage, '650 mg tablet');
    expect(jsonDecode(m.scheduledTimes), ['09:00', '21:00']);
    expect(m.durationDays, 5);
    expect(m.instructions, 'After food');
    expect(m.purpose, 'Fever and pain');
  });

  testWidgets('pick a suggestion: its usual schedule is filled in', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('medicine_quick_text')),
        matching: find.byType(EditableText),
      ),
      'thyro',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('medicine_suggestion_Levothyroxine')),
    );
    await tester.pump();
    expect(find.text('Reminders at 8:00 AM'), findsOneWidget);
    final selected = tester.widget<Widget>(
      find.byKey(const ValueKey('medicine_food_FoodTiming.empty')),
    );
    expect(selected, isNotNull);
  });

  testWidgets('quick add fits 320 px at 2.0x text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    await pump(tester, scale: 2);
    tester.view.physicalSize = const Size(320, 800);
    await tester.pump();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('medicine_quick_text')),
        matching: find.byType(EditableText),
      ),
      'Amoxicillin 500 mg thrice 7 days',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
