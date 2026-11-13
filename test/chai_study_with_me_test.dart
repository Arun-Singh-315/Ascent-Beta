import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/chai_break/chai_break_provider.dart';
import 'package:ascent/features/chai_break/chai_break_screen.dart';

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  group('Study with Me (Chai Session) Tests', () {
    test(
      'ChaiBreakNotifier supports studyWithMe mode, task linking, and study session lifecycle',
      () async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );

        final notifier = container.read(chaiBreakProvider.notifier);

        // 1. Initial mode defaults to mindfulPause
        expect(container.read(chaiBreakProvider).mode, ChaiBreakMode.mindfulPause);
        expect(container.read(chaiBreakProvider).linkedTaskId, isNull);

        // 2. Switch to studyWithMe mode
        notifier.setMode(ChaiBreakMode.studyWithMe);
        expect(container.read(chaiBreakProvider).mode, ChaiBreakMode.studyWithMe);
        // Default study preset should be 25 minutes (1500s)
        expect(container.read(chaiBreakProvider).totalDurationSeconds, 1500);

        // 3. Link a task from Things
        notifier.linkTask(42, 'Algorithms Practice');
        expect(container.read(chaiBreakProvider).linkedTaskId, 42);
        expect(container.read(chaiBreakProvider).linkedTaskTitle, 'Algorithms Practice');

        // 4. Start 25m study timer
        notifier.setPresetMinutes(25);
        expect(container.read(chaiBreakProvider).isRunning, true);
        expect(container.read(chaiBreakProvider).hasStarted, true);
        expect(container.read(chaiBreakProvider).totalDurationSeconds, 1500);

        // 5. Unlink task
        notifier.unlinkTask();
        expect(container.read(chaiBreakProvider).linkedTaskId, isNull);
        expect(container.read(chaiBreakProvider).linkedTaskTitle, isNull);

        // 6. Stop/finish
        notifier.stop();
        expect(container.read(chaiBreakProvider).isRunning, false);

        await Future<void>.delayed(const Duration(milliseconds: 20));
        container.dispose();
      },
    );

    testWidgets(
      'ChaiBreakScreen renders Study with Me mode, task link pill, and presets cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
            ],
            child: const MaterialApp(home: ChaiBreakScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify segment exists
        expect(find.text('Study with Me'), findsOneWidget);
        expect(find.text('Mindful Pause'), findsOneWidget);
        expect(find.text('Brew with Me'), findsOneWidget);

        // Tap Study with Me segment
        await tester.tap(find.text('Study with Me'));
        await tester.pumpAndSettle();

        // Verify Study with Me specific UI elements
        expect(find.text('25m Flow'), findsOneWidget);
        expect(find.text('45m Deep'), findsOneWidget);
        expect(find.text('60m Marathon'), findsOneWidget);
        expect(find.textContaining('Link a task'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Study with Me UI is immune to overflow at 320px with 2.0x text scale (Rule 13)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 700),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: const ChaiBreakScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Switch to Study with Me
        await tester.tap(find.text('Study with Me'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );
  });
}
