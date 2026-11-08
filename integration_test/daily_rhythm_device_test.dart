import 'dart:io';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_life_shelf.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets(
    'Daily rhythm shows today totals and expands within its own card',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.waterDao.addWater(750);
      final now = DateTime.now();
      for (var i = 0; i < 13; i++) {
        await db
            .into(db.historyEventTable)
            .insert(
              HistoryEventTableCompanion.insert(
                id: 'rhythm-qa-$i',
                module: 'breaks',
                entityId: 'pause-$i',
                action: 'completed',
                title: 'Test pause',
                occurredAt: i == 12
                    ? now.subtract(const Duration(days: 1))
                    : now,
              ),
            );
      }
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          todayWalkDistanceStreamProvider.overrideWith(
            (ref) => Stream.value(1250),
          ),
        ],
      );
      Future<void> flush() async {
        for (var i = 0; i < 10; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await t.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> screen({bool dark = false, double scale = 1}) async {
        await t.pumpWidget(const SizedBox());
        await flush();
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: HomeTheme.from(
                dark ? AscentTheme.dark() : AscentTheme.light(),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        HomeShortcutPanel(
                          shortcuts: [
                            'hydration',
                            'walk',
                            'chai-break',
                            'medicine',
                          ],
                        ),
                        SizedBox(height: 24),
                        HomeLifeShelf(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await flush();
      }

      var converted = false;
      Future<void> capture(String name) async {
        if (!converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
        }
        await t.pump();
        final data = await binding.takeScreenshot(name);
        await File(
          '${(await getTemporaryDirectory()).path}/rhythm-$name.png',
        ).writeAsBytes(data);
      }

      await screen();
      expect(find.text('750 ml today'), findsNWidgets(2));
      expect(find.text('1.25 km today'), findsNWidgets(2));
      expect(find.text('12 pauses today'), findsNWidgets(2));
      expect(find.text('0/0 taken today'), findsNWidgets(2));
      await capture('today-totals');
      final water = find.byKey(const ValueKey('home_routine_hydration'));
      await t.ensureVisible(water);
      await t.tap(water);
      await flush();
      expect(
        t.getSize(find.byKey(const ValueKey('rhythm_card_hydration'))).width,
        t.getSize(find.byKey(const ValueKey('home_life_shelf'))).width,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('rhythm_card_hydration')),
          matching: find.byKey(const ValueKey('rhythm_detail_hydration')),
        ),
        findsOneWidget,
      );
      await t.ensureVisible(find.text('Log water'));
      await capture('water-expanded');
      final move = find.byKey(const ValueKey('home_routine_walk'));
      await t.ensureVisible(move);
      await t.tap(move);
      await flush();
      expect(
        find.byKey(const ValueKey('rhythm_detail_hydration')),
        findsNothing,
      );
      expect(
        t.getSize(find.byKey(const ValueKey('rhythm_card_hydration'))).width,
        lessThan(
          t.getSize(find.byKey(const ValueKey('home_life_shelf'))).width,
        ),
      );
      await screen(dark: true, scale: 2);
      await t.ensureVisible(water);
      await t.tap(water);
      await flush();
      await t.ensureVisible(find.text('Log water'));
      await capture('large-text-dark');
      expect(t.takeException(), isNull);
      expect(await db.waterDao.watchTodayWaterMl().first, 750);
      await t.pumpWidget(const SizedBox());
      await flush();
      container.dispose();
      await db.close();
    },
  );
}
