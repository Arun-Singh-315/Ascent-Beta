import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/features/onboarding/onboarding_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Render high-fidelity Apple-style Onboarding photos', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const outDir = '/home/arunsinghvisen/.gemini/antigravity/brain/6e5c0915-9ec5-4033-bc23-e754a7671354';

    for (final isDark in [true, false]) {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final repaintKey = GlobalKey();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: isDark ? AscentTheme.dark() : AscentTheme.light(),
            home: RepaintBoundary(
              key: repaintKey,
              child: const OnboardingShell(),
            ),
          ),
        ),
      );

      // Settle Step 0
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }

      // Capture Step 0 (Vision)
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final fileName = isDark ? 'onboarding_apple_vision_dark.png' : 'onboarding_apple_vision_light.png';
            final file = File('$outDir/$fileName');
            await file.writeAsBytes(byteData.buffer.asUint8List());
          }
          image.dispose();
        }
      });

      // Advance to Step 1 (Identity)
      container.read(onboardingProvider.notifier).setStep(1);
      container.read(onboardingProvider.notifier).updateNameRole('Arun', 'Study & Growth');
      container.read(onboardingProvider.notifier).setDateOfBirth(DateTime(1998, 6, 15)); // Gemini / Mithuna
      await tester.pump();

      // Enter text into field so checkmark shows
      final nameFinder = find.byKey(const ValueKey('onboarding_name'));
      if (nameFinder.evaluate().isNotEmpty) {
        await tester.enterText(nameFinder, 'Arun Singh');
      }

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }

      // Capture Step 1 (Identity & Cosmic verification)
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final fileName = isDark ? 'onboarding_apple_identity_dark.png' : 'onboarding_apple_identity_light.png';
            final file = File('$outDir/$fileName');
            await file.writeAsBytes(byteData.buffer.asUint8List());
          }
          image.dispose();
        }
      });

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    }
  });
}
