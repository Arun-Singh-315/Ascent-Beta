import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/features/chai_break/chai_break_provider.dart';
import 'package:ascent/features/chai_break/widgets/ambient_soundscape_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chai Break Offline Audio & Custom Music Tests', () {
    test(
      'All bundled ambient sound assets exist on disk with valid non-zero content',
      () {
        final presets = [
          SoundscapePreset.tapriCafeRain,
          SoundscapePreset.acousticLofi,
          SoundscapePreset.zenRiverChimes,
          SoundscapePreset.campfireWarmth,
        ];

        for (final preset in presets) {
          expect(
            preset.assetPath.isNotEmpty,
            true,
            reason: '${preset.title} assetPath must not be empty',
          );
          final file = File('assets/${preset.assetPath}');
          expect(
            file.existsSync(),
            true,
            reason: 'assets/${preset.assetPath} must exist on filesystem',
          );
          expect(
            file.lengthSync() > 10000,
            true,
            reason: 'assets/${preset.assetPath} must be non-trivial audio size',
          );
        }
      },
    );

    test('ChaiBreakState tracks custom song name, path and volume', () {
      const state = ChaiBreakState(
        selectedSoundscape: SoundscapePreset.customSystemAudio,
        customAudioPath: '/storage/music/my_study_beats.mp3',
        customAudioName: 'my_study_beats.mp3',
        volume: 0.9,
      );

      expect(state.isPlayingCustomAudio, true);
      expect(state.customAudioName, 'my_study_beats.mp3');
      expect(state.volume, 0.9);

      final updated = state.copyWith(
        selectedSoundscape: SoundscapePreset.tapriCafeRain,
        customAudioPath: null,
        customAudioName: null,
      );
      expect(updated.isPlayingCustomAudio, false);
      expect(updated.selectedSoundscape, SoundscapePreset.tapriCafeRain);
    });

    testWidgets('AmbientSoundscapeBar renders preset title and controls', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmbientSoundscapeBar(
              selectedSoundscape: SoundscapePreset.tapriCafeRain,
              isPlaying: true,
              isMuted: false,
              onSoundscapeChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Tapri Cafe & Rain'), findsOneWidget);
      expect(find.text('AMBIENCE: '), findsOneWidget);
    });

    testWidgets(
      'AmbientSoundscapeBar renders custom device song title when active',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AmbientSoundscapeBar(
                selectedSoundscape: SoundscapePreset.customSystemAudio,
                isPlaying: true,
                isMuted: false,
                customAudioName: 'lofi_night_drive.mp3',
                onSoundscapeChanged: (_) {},
              ),
            ),
          ),
        );

        await tester.pump();
        expect(find.text('MY SONG: '), findsOneWidget);
        expect(find.text('lofi_night_drive.mp3'), findsOneWidget);
      },
    );
  });

  group('HomeHeader Resilient Layout Tests', () {
    testWidgets(
      'HomeHeader handles very long user names gracefully without crashing or squishing',
      (tester) async {
        final now = DateTime.now();
        final longNamedProfile = UserProfile(
          id: 1,
          name: 'Arun Singh Visen Alexander The Great',
          targetRole: 'Staff Principal Systems Engineer',
          targetCompanies: '["Google", "Stripe"]',
          weeklyHoursAvailable: 30,
          preferredStudyWindow: 'morning',
          skillSelfRatings: '{}',
          createdAt: now,
          updatedAt: now,
          onboardingComplete: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              homeStreakVisibleProvider.overrideWithValue(true),
              currentStreakStreamProvider.overrideWith(
                (ref) => Stream.value(14),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: HomeHeader(profile: longNamedProfile),
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Ensure full name and role are rendered cleanly
        expect(
          find.text('Arun Singh Visen Alexander The Great'),
          findsOneWidget,
        );
        expect(find.text('Staff Principal Systems Engineer'), findsOneWidget);
        // A legacy activity count must not invent a study streak.
        expect(find.text('Start'), findsOneWidget);
        // Ensure profile avatar with initial 'A' is present
        expect(find.text('A'), findsOneWidget);
      },
    );
  });
}
