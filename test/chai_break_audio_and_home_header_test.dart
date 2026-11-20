import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
