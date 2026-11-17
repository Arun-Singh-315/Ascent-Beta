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

  testWidgets('Render high-fidelity Onboarding 6-Screen photos', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const outDir = '/home/arunsinghvisen/.gemini/antigravity/brain/c4562752-ff66-4729-a56a-7b6c5dbf97f2';

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
          theme: AscentTheme.light(),
          home: RepaintBoundary(
            key: repaintKey,
            child: const OnboardingShell(),
          ),
        ),
      ),
    );

    Future<void> captureScreen(String fileName) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final file = File('$outDir/$fileName');
            await file.writeAsBytes(byteData.buffer.asUint8List());
          }
          image.dispose();
        }
      });
    }

    // Screen 1: Welcome
    await captureScreen('onboarding_1_welcome.png');

    // Screen 2: What you get
    container.read(onboardingProvider.notifier).setStep(1);
    await tester.pump();
    await captureScreen('onboarding_2_what_you_get.png');

    // Screen 3: Your Name
    container.read(onboardingProvider.notifier).setStep(2);
    container.read(onboardingProvider.notifier).updateNameRole('Arun', 'Study and growth');
    await tester.pump();
    final nameFinder = find.byKey(const ValueKey('onboarding_name'));
    if (nameFinder.evaluate().isNotEmpty) {
      await tester.enterText(nameFinder, 'Arun');
      await tester.pump();
    }
    await captureScreen('onboarding_3_your_name.png');

    // Screen 4: Birthday
    container.read(onboardingProvider.notifier).setStep(3);
    container.read(onboardingProvider.notifier).setDateOfBirth(DateTime(2000, 6, 18));
    await tester.pump();
    await captureScreen('onboarding_4_birthday.png');

    // Screen 5: Your Climb
    container.read(onboardingProvider.notifier).setStep(4);
    container.read(onboardingProvider.notifier).setFocusArea('Focus and flow');
    await tester.pump();
    await captureScreen('onboarding_5_your_climb.png');

    // Screen 6: Ready
    container.read(onboardingProvider.notifier).setStep(5);
    await tester.pump();
    await captureScreen('onboarding_6_ready.png');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
