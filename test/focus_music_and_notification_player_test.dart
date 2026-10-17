import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/features/focus/focus_screen.dart';
import 'package:ascent/features/study_plan/lecture_focus_player_sheet.dart';
import 'package:ascent/shared/widgets/music_companion_card.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestLearningHub extends LearningHubNotifier {
  @override
  LearningHubState build() => LearningHubState(
        courses: [
          Course(
            id: 'test_course',
            title: 'System Design Masterclass',
            modules: [
              CourseModule(
                id: 1,
                title: 'Foundations',
                lectures: [
                  const Lecture(
                    id: 1,
                    moduleId: 1,
                    moduleTitle: 'Foundations',
                    title: 'Architecture Patterns',
                    durationSeconds: 1800,
                  ),
                ],
              ),
            ],
          ),
        ],
        activeCourseId: 'test_course',
        activeLectureId: 1,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const musicChannel = MethodChannel('ascent/music');
  const liveSessionChannel = MethodChannel('ascent/live-sessions');

  late Map<String, dynamic> musicStatus;
  late List<MethodCall> musicCalls;
  late List<MethodCall> liveCalls;

  setUp(() {
    musicStatus = {'access': false};
    musicCalls = [];
    liveCalls = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(musicChannel, (call) async {
          musicCalls.add(call);
          if (call.method == 'status') return musicStatus;
          if (call.method == 'control') return true;
          if (call.method == 'settings') return null;
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveSessionChannel, (call) async {
          liveCalls.add(call);
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(musicChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(liveSessionChannel, null);
  });

  Widget wrapWithTheme(Widget child, {bool isDark = true}) {
    return MaterialApp(
      theme: isDark ? AscentTheme.dark() : AscentTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('MusicCompanionCard UI & Interaction Tests', () {
    testWidgets('shows connect invitation in clean companion capsule when access is false', (
      tester,
    ) async {
      musicStatus = {'access': false};
      await tester.pumpWidget(wrapWithTheme(const MusicCompanionCard()));
      await tester.pumpAndSettle();

      expect(find.text('Study Soundtrack'), findsOneWidget);
      expect(find.text('Connect music'), findsOneWidget);
      expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);

      // Tap connect music opens explanation dialog
      await tester.tap(find.text('Connect music'));
      await tester.pumpAndSettle();

      expect(find.text('Connect your music'), findsOneWidget);
      expect(find.textContaining('broad notification access'), findsOneWidget);

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(musicCalls.where((c) => c.method == 'settings'), hasLength(1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('shows idle status when access is granted but no song is playing', (
      tester,
    ) async {
      musicStatus = {'access': true};
      await tester.pumpWidget(wrapWithTheme(const MusicCompanionCard()));
      await tester.pumpAndSettle();

      expect(find.text('Study Soundtrack'), findsOneWidget);
      expect(find.textContaining('Play audio in your music app'), findsOneWidget);
      expect(find.byTooltip('Music access settings'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('shows active track with animated equalizer and controls when music is playing', (
      tester,
    ) async {
      musicStatus = {
        'access': true,
        'title': 'Weightless',
        'artist': 'Marconi Union',
        'source': 'Spotify',
        'package': 'com.spotify.music',
        'playing': true,
        'toggle': true,
        'next': true,
      };

      await tester.pumpWidget(wrapWithTheme(const MusicCompanionCard()));
      await tester.pumpAndSettle();

      // Track details
      expect(find.text('Weightless'), findsOneWidget);
      expect(find.textContaining('Marconi Union'), findsOneWidget);
      expect(find.textContaining('Spotify'), findsOneWidget);
      expect(find.textContaining('Playing'), findsOneWidget);

      // Playback action buttons
      expect(find.byTooltip('Pause music'), findsOneWidget);
      expect(find.byTooltip('Next track'), findsOneWidget);

      // Tap pause
      await tester.tap(find.byTooltip('Pause music'));
      await tester.pumpAndSettle();

      expect(musicCalls.where((c) => c.method == 'control'), hasLength(1));
      expect(
        musicCalls.firstWhere((c) => c.method == 'control').arguments,
        {
          'package': 'com.spotify.music',
          'action': 'toggle',
        },
      );

      // Tap next
      await tester.tap(find.byTooltip('Next track'));
      await tester.pumpAndSettle();

      expect(musicCalls.where((c) => c.method == 'control'), hasLength(2));
      expect(
        musicCalls.lastWhere((c) => c.method == 'control').arguments,
        {
          'package': 'com.spotify.music',
          'action': 'next',
        },
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('disables next button when next capability is false', (
      tester,
    ) async {
      musicStatus = {
        'access': true,
        'title': 'Deep Focus',
        'artist': 'Study Music',
        'source': 'YouTube Music',
        'package': 'com.google.android.apps.youtube.music',
        'playing': false,
        'toggle': true,
        'next': false,
      };

      await tester.pumpWidget(wrapWithTheme(const MusicCompanionCard()));
      await tester.pumpAndSettle();

      expect(find.text('Deep Focus'), findsOneWidget);
      expect(find.byTooltip('Play music'), findsOneWidget);

      final nextButton = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == 'Next track',
        ),
      );
      expect(nextButton.onPressed, isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('gracefully handles large text scale factor without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      musicStatus = {
        'access': true,
        'title': 'Very Long Ambient Track Name For Deep Focus And Cognitive Performance',
        'artist': 'Super Long Soundscapes & Binaural Beats Collective',
        'source': 'Spotify',
        'package': 'com.spotify.music',
        'playing': true,
        'toggle': true,
        'next': true,
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.dark(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: const SingleChildScrollView(child: MusicCompanionCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });

  group('NotificationService Action Constants & Session Integration', () {
    test('defines required notification player action constants', () {
      expect(NotificationService.actionPause, 'action_pause');
      expect(NotificationService.actionResume, 'action_resume');
      expect(NotificationService.actionRewind, 'action_rewind');
      expect(NotificationService.actionForward, 'action_forward');
      expect(NotificationService.actionDone, 'action_done');
    });

    test('showOngoingSessionNotification passes totalSeconds and parameters to native bridge', () async {
      await NotificationService.instance.showOngoingSessionNotification(
        title: 'Microservices Architecture',
        body: 'Distributed Systems',
        subText: 'Lecture Active',
        elapsedSeconds: 120,
        totalSeconds: 1800,
        isPaused: false,
        payload: '/learning',
      );

      expect(liveCalls.where((c) => c.method == 'update'), isNotEmpty);
      final updateCall = liveCalls.firstWhere((c) => c.method == 'update');
      expect(updateCall.arguments['title'], 'Microservices Architecture');
      expect(updateCall.arguments['body'], 'Distributed Systems');
      expect(updateCall.arguments['route'], '/learning');
      expect(updateCall.arguments['elapsed'], 120);
      expect(updateCall.arguments['total'], 1800);
      expect(updateCall.arguments['paused'], false);
    });
  });

  group('Integration in Focus & Lecture Sheet Layouts', () {
    testWidgets('FocusScreen positions MusicCompanionCard below clock and summary strip', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await db
          .into(db.userProfileTable)
          .insert(
            UserProfileTableCompanion.insert(
              name: 'Arun Singh Visen',
              onboardingComplete: const drift.Value(true),
            ),
          );
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Focus Timer': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: const FocusScreen(),
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }

        final musicFinder = find.byType(MusicCompanionCard);
        expect(musicFinder, findsOneWidget);

        final stripFinder = find.text('Today across all tasks:');
        expect(stripFinder, findsOneWidget);

        final musicY = tester.getTopLeft(musicFinder).dy;
        final stripY = tester.getTopLeft(stripFinder).dy;
        expect(musicY > stripY, isTrue, reason: 'Music companion must be docked below the summary strip and clock, not at the top');
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
        container.dispose();
        var closed = false;
        final closing = db.close().then((_) => closed = true);
        for (var i = 0; i < 20 && !closed; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await closing;
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('LectureFocusPlayerSheet positions MusicCompanionCard below player controls', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          learningHubProvider.overrideWith(_TestLearningHub.new),
        ],
      );
      try {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: const Scaffold(
                body: SizedBox(
                  height: 1200,
                  width: 400,
                  child: LectureFocusPlayerSheet(),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }

        final musicFinder = find.byType(MusicCompanionCard);
        expect(musicFinder, findsOneWidget);

        final titleFinder = find.textContaining('Lecture');
        expect(titleFinder, findsWidgets);

        final musicY = tester.getTopLeft(musicFinder).dy;
        final titleY = tester.getTopLeft(titleFinder.first).dy;
        expect(
          musicY > titleY,
          isTrue,
          reason:
              'Music companion must be docked beneath the lecture title and player controls',
        );
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
        container.dispose();
        var closed = false;
        final closing = db.close().then((_) => closed = true);
        for (var i = 0; i < 20 && !closed; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await closing;
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
