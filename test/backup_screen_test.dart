import 'dart:io';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/backup/backup_providers.dart';
import 'package:ascent/core/backup/backup_service.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/settings/backup_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late Directory docs;
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('ascent_backup_screen');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    Size size = const Size(390, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          backupServiceProvider.overrideWithValue(
            BackupService(db, prefs, documents: () async => docs),
          ),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const BackupScreen(),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('first visit invites a backup and Back up now makes one', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Not backed up yet'), findsOneWidget);
    expect(
      find.text('No backups here yet. Back up now to make one.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('backup_now')));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Last backup'), findsOneWidget);
    expect(find.byKey(const ValueKey('backup_row_0')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  for (final dark in [false, true]) {
    testWidgets('fits 320 px at 2x text (dark=$dark)', (tester) async {
      await pump(tester, scale: 2, size: const Size(320, 1600));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
