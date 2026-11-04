import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_editor_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSheet({Medicine? medicine}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: AscentTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MedicineEditorSheet(medicine: medicine),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'MedicineEditorSheet displays 4 categories and smart defaults',
    (tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      // Verify category tabs exist
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Homeo'), findsOneWidget);
      expect(find.text('Ayurveda'), findsOneWidget);
      expect(find.text('Supplement'), findsOneWidget);

      // Default is General
      expect(find.text('Paracetamol'), findsOneWidget);

      // Switch to Homeopathy
      await tester.tap(find.text('Homeo'));
      await tester.pumpAndSettle();

      // Homeopathy suggestions and defaults appear
      expect(find.text('Arnica 30C'), findsOneWidget);
      expect(find.text('4 sugar pills'), findsOneWidget);
      expect(find.text('15m before/after food'), findsOneWidget);

      // Switch to Ayurveda
      await tester.tap(find.text('Ayurveda'));
      await tester.pumpAndSettle();

      expect(find.text('Ashwagandha'), findsOneWidget);
      expect(find.text('With warm water'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping a remedy suggestion fills the name and saves cleanly',
    (tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.pumpAndSettle();

      // Switch to Homeo
      await tester.tap(find.text('Homeo'));
      await tester.pumpAndSettle();

      // Tap 'Arnica 30C'
      await tester.tap(find.text('Arnica 30C'));
      await tester.pumpAndSettle();

      expect(find.text('Arnica 30C'), findsWidgets);

      // Tap Save
      await tester.tap(find.text('Add to Schedule'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify saved in database
      final meds = await db.select(db.medicineTable).get();
      expect(meds.length, 1);
      expect(meds.first.name, 'Arnica 30C');
      expect(meds.first.dosage, '4 sugar pills');
    },
  );

  testWidgets(
    'MedicineEditorSheet passes Rule 13 overflow immunity at 320px with 2.0x text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320 * 3.0, 800 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2.0),
          ),
          child: buildSheet(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Homeo'), findsOneWidget);
    },
  );
}
