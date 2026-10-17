import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/shared/widgets/music_companion_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Lecture Activity Non-Tappable & No-Timer UI Tests', () {
    testWidgets(
      'Lecture activity is non-tappable, has no play button, and displays no elapsed timer',
      (tester) async {
        final lectureActivity = TodayActivityItem(
          id: 'lecture_dsa_101',
          title: 'Algorithms: Dynamic Programming',
          sourceType: 'lecture',
          learningCourseId: 'dsa_course',
          learningLectureId: 101,
          status: TodayActivityStatus.inProgress,
          elapsedSecondsToday: 245,
          categoryTag: 'Study',
          kind: ActivityKind.duration,
          targetMinutes: 30,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(activity: lectureActivity),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Title is displayed
        expect(find.text('Algorithms: Dynamic Programming'), findsOneWidget);

        // 2. No timer countdown or elapsed seconds text (e.g. "04:05" or "245s" or "/ 30m")
        expect(find.textContaining('04:05'), findsNothing);
        expect(find.textContaining('/ 30m'), findsNothing);
        expect(find.textContaining('tracked'), findsNothing);

        // 3. Subtitle displays clean status without ticking time
        expect(find.text('Lecture in progress'), findsOneWidget);

        // 4. NO play or pause buttons on the activity row to avoid player crossover
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
        expect(find.byIcon(Icons.pause_rounded), findsNothing);

        // 5. Tapping on the row does not trigger player sheet or modal
        await tester.tap(find.text('Algorithms: Dynamic Programming'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(Dialog), findsNothing);

        // 6. Checkbox circle displays headphone/lecture icon and is not interactive
        expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.headphones_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
      },
    );

    testWidgets(
      'Completed lecture activity displays done state without timer text',
      (tester) async {
        final completedLecture = TodayActivityItem(
          id: 'lecture_dsa_102',
          title: 'Algorithms: Graphs BFS',
          sourceType: 'lecture',
          learningCourseId: 'dsa_course',
          learningLectureId: 102,
          status: TodayActivityStatus.done,
          elapsedSecondsToday: 900,
          categoryTag: 'Study',
          kind: ActivityKind.duration,
          targetMinutes: 15,
          completedAt: DateTime(2026, 10, 17, 14, 30),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(activity: completedLecture),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Algorithms: Graphs BFS'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.textContaining('/ 15m'), findsNothing);
        expect(find.textContaining('tracked'), findsNothing);
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      },
    );
  });

  group('Music Companion Pause Persistence Tests', () {
    const channel = MethodChannel('ascent/music');
    late Map<String, dynamic> mockStatus;
    late List<MethodCall> calls;

    setUp(() {
      calls = [];
      mockStatus = {
        'access': true,
        'title': 'Midnight Ambient',
        'artist': 'Focus Beats',
        'source': 'Spotify',
        'package': 'com.spotify.music',
        'playing': true,
        'toggle': true,
        'next': true,
      };

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'status') return mockStatus;
            if (call.method == 'control') {
              // When pause is sent, simulate player state becoming paused
              if (call.arguments['action'] == 'toggle') {
                mockStatus['playing'] = !(mockStatus['playing'] as bool);
              }
              return true;
            }
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets(
      'Pausing the song from app keeps the track view visible as paused instead of removing it',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: MusicCompanionCard()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Track is actively playing
        expect(find.text('Midnight Ambient'), findsOneWidget);
        expect(find.textContaining('Focus Beats'), findsOneWidget);
        expect(find.textContaining('Playing'), findsOneWidget);
        expect(find.byTooltip('Pause music'), findsOneWidget);

        // 2. User taps Pause from the app
        await tester.tap(find.byTooltip('Pause music'));
        await tester.pumpAndSettle();

        // 3. Verify control call was sent
        expect(
          calls.any(
            (c) =>
                c.method == 'control' &&
                c.arguments['action'] == 'toggle' &&
                c.arguments['package'] == 'com.spotify.music',
          ),
          isTrue,
        );

        // 4. THE TRACK VIEW MUST STILL BE VISIBLE AND NOT REMOVED!
        expect(find.text('Midnight Ambient'), findsOneWidget);
        expect(find.textContaining('Focus Beats'), findsOneWidget);
        expect(find.textContaining('Paused'), findsOneWidget);
        // It should NOT be reverted to the empty idle invite
        expect(
          find.text('Play audio in your music app for focus ambience.'),
          findsNothing,
        );

        // 5. Toggle button is now Play music to resume
        expect(find.byTooltip('Play music'), findsOneWidget);

        // 6. Tapping Play resumes playback
        await tester.tap(find.byTooltip('Play music'));
        await tester.pumpAndSettle();
        expect(find.text('Midnight Ambient'), findsOneWidget);
        expect(find.byTooltip('Pause music'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'Track view persists even if native status returns brief null title right after pause',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: MusicCompanionCard()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Midnight Ambient'), findsOneWidget);

        // Simulate external music player momentarily clearing title on pause
        mockStatus = {
          'access': true,
          'package': 'com.spotify.music',
          'source': 'Spotify',
          'title': null,
          'artist': null,
          'playing': false,
          'toggle': true,
        };

        await tester.tap(find.byTooltip('Pause music'));
        await tester.pumpAndSettle();

        // The card should still preserve the known song rather than removing the view!
        expect(find.text('Midnight Ambient'), findsOneWidget);
        expect(
          find.text('Play audio in your music app for focus ambience.'),
          findsNothing,
        );
        expect(find.byTooltip('Play music'), findsOneWidget);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });
}
