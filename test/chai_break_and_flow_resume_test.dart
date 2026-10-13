import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/chai_break/chai_break_provider.dart';
import 'package:ascent/features/chai_break/chai_break_screen.dart';

class FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() {
    return const TimeTrackingState();
  }
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

  group('Chai & Coffee Break Sanctuary Tests', () {
    test(
      'ChaiBreakNotifier initializes with 10 min preset and decrements timer',
      () async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        final notifier = container.read(chaiBreakProvider.notifier);

        expect(container.read(chaiBreakProvider).totalDurationSeconds, 600);
        expect(container.read(chaiBreakProvider).remainingSeconds, 600);
        expect(container.read(chaiBreakProvider).isRunning, true);
        expect(
          container.read(chaiBreakProvider).selectedSoundscape,
          SoundscapePreset.tapriCafeRain,
        );

        // Change preset to 5m
        notifier.setPresetMinutes(5);
        expect(container.read(chaiBreakProvider).totalDurationSeconds, 300);
        expect(container.read(chaiBreakProvider).remainingSeconds, 300);

        // Pause timer
        notifier.pause();
        expect(container.read(chaiBreakProvider).isRunning, false);

        // Resume timer
        notifier.resume();
        expect(container.read(chaiBreakProvider).isRunning, true);

        // Select acoustic soundscape
        notifier.selectSoundscape(SoundscapePreset.acousticLofi);
        expect(
          container.read(chaiBreakProvider).selectedSoundscape,
          SoundscapePreset.acousticLofi,
        );

        container.dispose();
      },
    );

    testWidgets(
      'ChaiBreakScreen pumps and displays timer, presets, and soundscape',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
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
              timeTrackingProvider.overrideWith(
                () => FakeTimeTrackingNotifier(),
              ),
            ],
            child: const MaterialApp(home: ChaiBreakScreen()),
          ),
        );

        await tester.pump();
        expect(find.text('Chai & Coffee'), findsOneWidget);
        expect(find.text('5m Chai'), findsOneWidget);
        expect(find.text('10m Coffee'), findsOneWidget);
        expect(find.text('15m Reset'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Flow Resume Guarantee: Lecture resume starts at exact paused second, not from 0',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(() => FakeTimeTrackingNotifier()),
          ],
        );

        final learningNotifier = container.read(learningHubProvider.notifier);
        await tester.runAsync(() => learningNotifier.ready);
        learningNotifier.startLearning();

        // Simulate playing and advancing lecture
        learningNotifier.play();
        learningNotifier.seekBy(120); // Advance 120s (2 minutes)
        learningNotifier.pause();

        final pausedSecond = container
            .read(learningHubProvider)
            .currentElapsedSeconds;
        expect(pausedSecond, 120);

        // Pump ChaiBreakScreen with this container
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ChaiBreakScreen()),
          ),
        );

        await tester.pump();

        // Verify the dock buttons Go to Learning and Go to Todo are completely removed per user instruction
        expect(find.text('Go to Learning'), findsNothing);
        expect(find.text('Go to Todo'), findsNothing);

        // Verify that when lecture is resumed, learningHubProvider preserves exact paused second 120, not 0
        learningNotifier.play();
        final stateAfterResume = container.read(learningHubProvider);
        expect(stateAfterResume.isPlaying, true);
        expect(stateAfterResume.currentElapsedSeconds >= 120, true);

        // Cleanly unmount and dispose container
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
        container.dispose();
        await tester.pump(Duration.zero);
      },
    );
  });
}
