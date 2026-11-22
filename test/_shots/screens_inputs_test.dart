import 'dart:io';
import 'dart:ui' as ui;

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/thought_wall/board/thought_board_screen.dart';
import 'package:ascent/features/today/things_hub_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final (name, screen) in [
    ('mind', const ThoughtBoardScreen() as Widget),
    ('things', const ThingsHubScreen() as Widget),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('render $name dark=$dark', (t) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        await t.runAsync(() async {
          await db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(content: 'Plan the weekend trip'),
          );
          await db.taskDao.insertTask(
            TaskTableCompanion.insert(
              title: 'Review design docs',
              plannedDate: drift.Value(DateTime.now()),
            ),
          );
        });
        t.view.physicalSize = const Size(780, 1688);
        t.view.devicePixelRatio = 2;
        addTearDown(t.view.reset);
        final key = GlobalKey();
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: dark ? AscentTheme.dark() : AscentTheme.light(),
              home: RepaintBoundary(key: key, child: screen),
            ),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump(const Duration(milliseconds: 100));
        }
        await t.runAsync(() async {
          final b =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 1);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File(
            'test/_shots/${name}_${dark ? 'dark' : 'light'}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
        });
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 1));
        await t.runAsync(db.close);
      });
    }
  }
}
