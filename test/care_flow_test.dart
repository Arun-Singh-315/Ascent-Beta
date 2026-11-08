import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/care_repository.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';
import 'package:ascent/shared/widgets/ascent_snack_bar.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    if (Platform.environment['ASCENT_QA_CAPTURE'] == '1') {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester t, String name) async {
    if (Platform.environment['ASCENT_QA_CAPTURE'] != '1') return;
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('care_preview')),
    );
    await t.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/ascent-care-$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'care plan, journal and medicine context at mobile scale=$scale dark=$dark',
        (t) async {
          t.view.physicalSize = Size(scale == 2 ? 320 : 390, 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          final repo = CareRepository(db);
          final planId = await repo.savePlan(
            title: 'Thyroid care',
            person: 'My care',
            clinician: 'Dr Meera · Family clinic',
            notes: 'Ask about the next review and bring previous reports.',
            nextVisit: DateTime(2026, 12, 2),
          );
          await repo.addRecord(
            planId: planId,
            title: 'November review',
            notes: 'Questions noted for my next appointment.',
            recordedAt: DateTime(2026, 11, 8),
          );
          final service = MedicineService(db, syncAlerts: false);
          final medicineId = await service.addMedicine(
            name: 'My prescribed medicine',
            dosage: 'As prescribed',
            scheduledTimes: ['08:00'],
            durationDays: 7,
            startDate: DateTime.now(),
            carePlanId: planId,
            purpose: 'Purpose recorded from my prescription',
          );
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              medicineServiceProvider.overrideWithValue(service),
            ],
          );
          try {
            await t.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: RepaintBoundary(
                  key: const ValueKey('care_preview'),
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: dark
                        ? AscentTheme.dark(preset: DayThemePreset.merlotLinen)
                        : AscentTheme.light(),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                    home: const MedicineScreen(),
                  ),
                ),
              ),
            );
            await flush(t);
            await t.tap(find.byKey(const ValueKey('medicine_view_plans')));
            await flush(t);
            await capture(
              t,
              '${dark ? 'dark' : 'light'}-${scale.toInt()}-plans',
            );
            await t.scrollUntilVisible(
              find.text('Thyroid care'),
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView).last,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await t.pumpAndSettle();
            await t.tap(find.text('Thyroid care'));
            await flush(t);
            expect(find.text('Dr Meera · Family clinic'), findsOneWidget);
            await capture(
              t,
              '${dark ? 'dark' : 'light'}-${scale.toInt()}-detail',
            );
            await t.scrollUntilVisible(
              find.text('Add report or note'),
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView).last,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await t.pumpAndSettle();
            await t.tap(find.text('Add report or note'));
            await t.pumpAndSettle();
            await t.enterText(find.byType(TextField).first, 'Visit questions');
            await t.enterText(
              find.byType(TextField).last,
              'Bring my earlier report.',
            );
            await t.ensureVisible(find.text('Save record'));
            await t.tap(find.text('Save record'));
            await flush(t);
            expect(
              await t.runAsync(() => repo.watchRecords(planId).first),
              hasLength(2),
            );
            await t.scrollUntilVisible(
              find.text('Visit questions'),
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView).last,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await capture(
              t,
              '${dark ? 'dark' : 'light'}-${scale.toInt()}-journal',
            );
            await t.scrollUntilVisible(
              find.text('Edit record').first,
              100,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView).last,
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await t.pumpAndSettle();
            await t.tap(find.text('Edit record').first);
            await t.pumpAndSettle();
            await t.enterText(
              find.byType(TextField).first,
              'Updated visit questions',
            );
            await t.ensureVisible(find.text('Save record'));
            await t.tap(find.text('Save record'));
            await flush(t);
            expect(
              (await t.runAsync(
                () => repo.watchRecords(planId).first,
              ))!.first.title,
              'Updated visit questions',
            );
            expect(
              (await db.medicineDao.getMedicineById(medicineId))!.carePlanId,
              planId,
            );
            expect(t.takeException(), isNull);
          } finally {
            await t.pumpWidget(const SizedBox());
            container.dispose();
            await t.pump(const Duration(seconds: 2));
            await db.close();
          }
        },
      );
    }
  }

  testWidgets('undo survives later feedback, is accessible, and runs once', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    var restored = 0;
    late BuildContext target;
    await t.pumpWidget(
      MaterialApp(
        theme: AscentTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            accessibleNavigation: true,
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              target = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    AscentSnackBar.undo(
      target,
      message: 'Your care record was removed',
      onUndo: () => restored++,
    );
    await t.pumpAndSettle();
    AscentSnackBar.success(target, message: 'Another update saved');
    await t.pump(const Duration(seconds: 12));
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Another update saved'), findsNothing);
    expect(t.widget<SnackBar>(find.byType(SnackBar)).action, isNotNull);
    await t.tap(find.text('Undo'));
    await t.pumpAndSettle();
    expect(restored, 1);
    expect(find.text('Another update saved'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
  });
}
