import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/daily_briefing_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/island_preferences_provider.dart';
import 'package:ascent/features/home/widgets/island_customization_sheet.dart';
import 'package:ascent/features/home/widgets/island_surface.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/walk/walk_tracking_service.dart';
import 'package:ascent/features/chai_break/chai_break_provider.dart';
import 'package:ascent/features/home/widgets/ascent_dynamic_island.dart';

class _Time extends TimeTrackingNotifier {
  _Time(this.initial);
  final TimeTrackingState initial;
  @override
  TimeTrackingState build() => initial;
  @override
  Future<void> pauseSession() async =>
      state = state.copyWith(isRunning: false, isPaused: true);
  @override
  Future<void> resumeSession() async =>
      state = state.copyWith(isRunning: true, isPaused: false);
  void end() => state = const TimeTrackingState();
}

class _Chai extends ChaiBreakNotifier {
  _Chai(this.initial);
  final ChaiBreakState initial;
  @override
  ChaiBreakState build() => initial;
  @override
  void togglePlayPause() =>
      state = state.copyWith(isRunning: !state.isRunning, hasStarted: true);
}

class _Learning extends LearningHubNotifier {
  _Learning(this.initial);
  final LearningHubState initial;
  @override
  LearningHubState build() => initial;
}

class _Walk extends WalkTrackingNotifier {
  _Walk(this.initial);
  final WalkTrackingState initial;
  @override
  WalkTrackingState build() => initial;
}

const _emptyBriefing = DailyBriefing(
  completedYesterday: 0,
  plannedYesterday: 0,
  finishedPlannedYesterday: 0,
  trackedMinutesYesterday: 0,
  dueToday: 0,
  overdue: 0,
  unscheduled: 0,
);
const _recap = DailyBriefing(
  completedYesterday: 3,
  plannedYesterday: 5,
  finishedPlannedYesterday: 3,
  trackedMinutesYesterday: 85,
  dueToday: 2,
  overdue: 4,
  unscheduled: 0,
);

class _Preferences extends IslandPreferencesNotifier {
  _Preferences(this.initial);
  final IslandPreferences initial;
  @override
  IslandPreferences build() => initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
    ]) {
      GoogleFonts.dmSans(fontWeight: weight);
      GoogleFonts.inter(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
  });
  late AppDatabase db;
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  TimeTrackingState focus() => TimeTrackingState(
    activeSession: TimeSession(
      id: 1,
      label: 'Design a little deeper',
      activityType: 'focus',
      categoryId: 1,
      startedAt: DateTime.now(),
      pausedIntervals: '[]',
      status: 'running',
      durationSeconds: 900,
      activityRefType: 'none',
      createdAt: DateTime.now(),
    ),
    elapsedSeconds: 900,
    isRunning: true,
  );

  Widget app({
    TimeTrackingState time = const TimeTrackingState(),
    ChaiBreakState chai = const ChaiBreakState(),
    DailyBriefing briefing = _emptyBriefing,
    List<Reminder> reminders = const [],
    bool expanded = false,
    bool autoPeek = false,
    bool dark = false,
    bool learning = false,
    WalkTrackingState walk = const WalkTrackingState(),
    double scale = 1,
    GlobalKey? capture,
    IslandPreferences preferences = const IslandPreferences(),
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      timeTrackingProvider.overrideWith(() => _Time(time)),
      chaiBreakProvider.overrideWith(() => _Chai(chai)),
      learningHubProvider.overrideWith(
        () => _Learning(
          LearningHubState(
            courses: const [],
            activeCourseId: '',
            activeLectureId: 1,
            isPlaying: learning,
            currentElapsedSeconds: 60,
          ),
        ),
      ),
      walkTrackingProvider.overrideWith(() => _Walk(walk)),
      islandLectureSessionProvider.overrideWith((ref) => Stream.value(null)),
      dailyBriefingProvider.overrideWith((ref, day) async => briefing),
      allRemindersProvider.overrideWith((ref) => Stream.value(reminders)),
      islandPreferencesProvider.overrideWith(() => _Preferences(preferences)),
    ],
    child: MaterialApp(
      theme: dark ? AscentTheme.dark() : AscentTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          backgroundColor: dark
              ? const Color(0xFF111B27)
              : const Color(0xFFF1F0EC),
          body: RepaintBoundary(
            key: capture,
            child: ColoredBox(
              color: dark ? const Color(0xFF111B27) : const Color(0xFFF1F0EC),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    const Text(
                      'FRIDAY, 30 OCTOBER',
                      style: TextStyle(fontSize: 11, letterSpacing: 2),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Make room for progress.',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AscentDynamicIsland(
                      initiallyExpanded: expanded,
                      autoPeek: autoPeek,
                    ),
                    const SizedBox(height: 20),
                    const Text('Mind palace', style: TextStyle(fontSize: 22)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settle(tester);
    await tester.tap(finder);
    await settle(tester);
  }

  Future<void> expand(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('dynamic_island_compact')));
    await settle(tester);
  }

  testWidgets(
    'New activity peeks once then settles; drag expands without a tap',
    (tester) async {
      await tester.pumpWidget(app(time: focus(), autoPeek: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const ValueKey('dynamic_island_expanded')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const ValueKey('dynamic_island_expanded')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 30));
      expect(
        find.byKey(const ValueKey('dynamic_island_expanded')),
        findsNothing,
      );
      await tester.drag(
        find.byKey(const ValueKey('island_drag_handle')),
        const Offset(0, 170),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const ValueKey('dynamic_island_expanded')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Idle and water-only workspace has no island or reserved space', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byKey(const ValueKey('dynamic_island_surface')), findsNothing);
  });
  testWidgets('Focus expands, pauses and resumes without losing its controls', (
    tester,
  ) async {
    await tester.pumpWidget(app(time: focus()));
    await settle(tester);
    expect(find.text('Focus · 15:00'), findsOneWidget);
    await expand(tester);
    await tester.tap(find.byKey(const ValueKey('island_toggle_focus')));
    await settle(tester);
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await settle(tester);
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.byTooltip('Collapse live activities'));
    await settle(tester);
    expect(
      find.byKey(const ValueKey('dynamic_island_compact')),
      findsOneWidget,
    );
  });
  testWidgets(
    'Concurrent focus, learning, walking, silent break and recap all remain accessible',
    (tester) async {
      await tester.pumpWidget(
        app(
          time: focus(),
          learning: true,
          walk: const WalkTrackingState(
            status: WalkTrackingStatus.tracking,
            distanceMeters: 1200,
          ),
          chai: const ChaiBreakState(
            isRunning: true,
            selectedSoundscape: SoundscapePreset.silentZen,
          ),
          briefing: _recap,
        ),
      );
      await settle(tester);
      expect(find.text('+4'), findsOneWidget);
      await expand(tester);
      for (final id in ['learning', 'walk', 'chai', 'focus']) {
        await tapVisible(tester, find.byKey(ValueKey('island_select_$id')));
        await settle(tester);
        expect(tester.takeException(), isNull);
      }
      await tapVisible(
        tester,
        find.byKey(const ValueKey('island_group_summary')),
      );
      expect(find.text('Overdue tasks'), findsOneWidget);
      await tapVisible(tester, find.byKey(const ValueKey('island_group_live')));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('island_select_chai')),
      );
      await settle(tester);
      expect(find.text('A moment to breathe'), findsOneWidget);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('island_toggle_chai')),
      );
      await settle(tester);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.byKey(const ValueKey('island_select_focus')), findsOneWidget);
    },
  );
  testWidgets('Final activity ending removes island completely', (
    tester,
  ) async {
    await tester.pumpWidget(app(time: focus()));
    await settle(tester);
    final context = tester.element(find.byType(AscentDynamicIsland));
    (ProviderScope.containerOf(context).read(timeTrackingProvider.notifier)
            as _Time)
        .end();
    await settle(tester);
    expect(find.byKey(const ValueKey('dynamic_island_surface')), findsNothing);
  });
  testWidgets(
    'Upcoming window excludes stale, inactive and distant reminders',
    (tester) async {
      Reminder reminder(int id, int minutes, {bool active = true}) => Reminder(
        id: id,
        title: 'Reminder $id',
        scheduledAt: DateTime.now().add(Duration(minutes: minutes)),
        isActive: active,
        alarmEnabled: true,
        alertSyncPending: false,
        createdAt: DateTime.now(),
      );
      await tester.pumpWidget(
        app(
          reminders: [
            reminder(1, -2),
            reminder(2, 20),
            reminder(3, 300),
            reminder(4, 10, active: false),
          ],
          expanded: true,
        ),
      );
      await settle(tester);
      expect(find.text('Reminder 2'), findsOneWidget);
      for (final id in [1, 3, 4]) {
        expect(find.text('Reminder $id'), findsNothing);
      }
      await tester.tap(
        find.byKey(const ValueKey('island_dismiss_report_button')),
      );
      await settle(tester);
      expect(
        find.byKey(const ValueKey('dynamic_island_surface')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'Recap uses recorded totals and labels all overdue work accurately',
    (tester) async {
      await tester.pumpWidget(app(briefing: _recap, expanded: true));
      await settle(tester);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('85'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Minutes tracked'), findsOneWidget);
      expect(find.text('Overdue tasks'), findsOneWidget);
    },
  );
  testWidgets(
    'Mobile light and dark glass, large text, multi-activity controls and upward collapse',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        for (final width in [320.0, 390.0]) {
          tester.view.physicalSize = Size(width, 1400);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpWidget(
            app(
              time: focus(),
              learning: true,
              scale: 2,
              dark: dark,
              chai: const ChaiBreakState(isRunning: true),
              expanded: true,
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
          await tester.fling(
            find.byKey(const ValueKey('island_drag_handle')),
            const Offset(0, -110),
            500,
          );
          await settle(tester);
          expect(
            find.byKey(const ValueKey('dynamic_island_compact')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );
  testWidgets(
    'Long press expands and an outside tap collapses without stopping focus',
    (tester) async {
      await tester.pumpWidget(app(time: focus()));
      await settle(tester);
      await tester.longPress(
        find.byKey(const ValueKey('dynamic_island_compact')),
      );
      await settle(tester);
      expect(
        find.byKey(const ValueKey('dynamic_island_expanded')),
        findsOneWidget,
      );
      await tester.tap(find.text('Make room for progress.'));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('dynamic_island_compact')),
        findsOneWidget,
      );
      expect(find.text('Focus · 15:00'), findsOneWidget);
    },
  );

  testWidgets(
    'Reading Chai stays idle, explicit start ticks, and completion clears live state',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(chaiBreakProvider).isRunning, isFalse);
      await tester.pump(const Duration(seconds: 3));
      expect(container.read(chaiBreakProvider).remainingSeconds, 600);
      container.read(chaiBreakProvider.notifier).setPresetMinutes(1);
      await tester.pump(const Duration(seconds: 2));
      expect(container.read(chaiBreakProvider).remainingSeconds, 58);
      container.read(chaiBreakProvider.notifier).pause();
      await tester.pump(const Duration(seconds: 2));
      expect(container.read(chaiBreakProvider).remainingSeconds, 58);
      container.read(chaiBreakProvider.notifier).resume();
      await tester.pump(const Duration(seconds: 58));
      expect(container.read(chaiBreakProvider).remainingSeconds, 0);
      expect(container.read(chaiBreakProvider).isRunning, isFalse);
      expect(container.read(chaiBreakProvider).hasStarted, isFalse);
    },
  );

  testWidgets(
    'Large expanded content scrolls on a short phone without collapsing',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          time: focus(),
          learning: true,
          scale: 2,
          chai: const ChaiBreakState(isRunning: true),
          expanded: true,
        ),
      );
      await settle(tester);
      await tester.dragFrom(const Offset(160, 550), const Offset(0, -240));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('dynamic_island_expanded')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('island_toggle_focus')),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('island_toggle_focus')));
      await settle(tester);
      expect(find.text('Resume'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Secondary bubble opens that activity directly', (tester) async {
    await tester.pumpWidget(
      app(time: focus(), chai: const ChaiBreakState(isRunning: true)),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('island_secondary_activity')));
    await settle(tester);
    expect(find.text('Tapri Cafe & Rain'), findsOneWidget);
    expect(find.byKey(const ValueKey('island_toggle_chai')), findsOneWidget);
  });

  testWidgets('Customization changes the live surface and persists choices', (
    tester,
  ) async {
    await tester.pumpWidget(app(time: focus(), expanded: true));
    await settle(tester);
    await tester.tap(find.byTooltip('Customize Dynamic Island'));
    await settle(tester);
    expect(find.byType(IslandCustomizationSheet), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('island_finish_midnight')),
    );
    expect(
      jsonDecode(prefs.getString(islandPreferencesKey)!)['finish'],
      'midnight',
    );
    await tapVisible(tester, find.text('Minimal'));
    expect(
      jsonDecode(prefs.getString(islandPreferencesKey)!)['density'],
      'minimal',
    );
    await tapVisible(tester, find.byTooltip('Close island customization'));
    await settle(tester);
    final surface = tester.widget<IslandSurface>(find.byType(IslandSurface));
    expect(surface.palette.isDark, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hidden context preferences leave live activities available', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        time: focus(),
        briefing: _recap,
        expanded: true,
        preferences: const IslandPreferences(
          showUpcoming: false,
          showRecap: false,
        ),
      ),
    );
    await settle(tester);
    expect(find.text('YOUR ACTIVITIES'), findsNothing);
    expect(find.byKey(const ValueKey('island_toggle_focus')), findsOneWidget);
  });

  testWidgets('Every finish and density remains readable at large text sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final finish in IslandFinish.values) {
      for (final density in IslandDensity.values) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          app(
            time: focus(),
            chai: const ChaiBreakState(isRunning: true),
            scale: 2,
            preferences: IslandPreferences(finish: finish, density: density),
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await expand(tester);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Recap can be hidden without leaving an empty island', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        briefing: _recap,
        preferences: const IslandPreferences(showRecap: false),
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('dynamic_island_surface')), findsNothing);
  });

  testWidgets(
    'Minimal mode hides the title and motion preference removes morph duration',
    (tester) async {
      await tester.pumpWidget(
        app(
          time: focus(),
          preferences: const IslandPreferences(
            density: IslandDensity.minimal,
            animate: false,
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Design a little deeper'), findsNothing);
      expect(find.text('Focus'), findsOneWidget);
      final animations = tester.widgetList<AnimatedSize>(
        find.descendant(
          of: find.byType(AscentDynamicIsland),
          matching: find.byType(AnimatedSize),
        ),
      );
      expect(animations.every((a) => a.duration == Duration.zero), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        app(
          briefing: _recap,
          preferences: const IslandPreferences(density: IslandDensity.minimal),
        ),
      );
      await settle(tester);
      expect(find.text('Daily recap'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    },
  );

  testWidgets(
    'Capture finishes, recap and walk statistics for visual inspection',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scenes = <(String, IslandPreferences, bool, bool)>[
        for (final finish in IslandFinish.values)
          (finish.name, IslandPreferences(finish: finish), false, false),
        ('recap', const IslandPreferences(), true, false),
        ('walk', const IslandPreferences(), false, true),
      ];
      for (final scene in scenes) {
        final key = GlobalKey();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          app(
            capture: key,
            expanded: true,
            preferences: scene.$2,
            time: scene.$3 || scene.$4 ? const TimeTrackingState() : focus(),
            briefing: scene.$3 ? _recap : _emptyBriefing,
            walk: scene.$4
                ? const WalkTrackingState(
                    status: WalkTrackingStatus.tracking,
                    durationSeconds: 900,
                    distanceMeters: 1200,
                    calories: 78,
                  )
                : const WalkTrackingState(),
          ),
        );
        await settle(tester);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/ascent-island-${scene.$1}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('Customization sheet fits narrow phones with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final scale in [1.0, 2.0]) {
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: key,
                child: const Scaffold(body: IslandCustomizationSheet()),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/ascent-island-customization${scale == 1 ? '' : '-large'}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });

  testWidgets('Paused visibility and reminder visibility are independent', (
    tester,
  ) async {
    final paused = focus().copyWith(isRunning: false, isPaused: true);
    await tester.pumpWidget(app(time: paused, expanded: true));
    await settle(tester);
    expect(find.text('Resume'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      app(
        time: paused,
        preferences: const IslandPreferences(showPaused: false),
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('dynamic_island_surface')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      app(
        preferences: const IslandPreferences(showUpcoming: false),
        reminders: [
          Reminder(
            id: 7,
            title: 'Next meeting',
            scheduledAt: DateTime.now().add(const Duration(minutes: 20)),
            isActive: true,
            alarmEnabled: true,
            alertSyncPending: false,
            createdAt: DateTime.now(),
          ),
        ],
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('dynamic_island_surface')), findsNothing);
  });

  testWidgets('Capture mobile live states for visual inspection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final dark in [false, true]) {
      for (final expanded in [false, true]) {
        final key = GlobalKey();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          app(
            time: focus(),
            chai: const ChaiBreakState(isRunning: true),
            expanded: expanded,
            dark: dark,
            capture: key,
          ),
        );
        await settle(tester);
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/ascent-island-${dark ? 'dark' : 'light'}${expanded ? '' : '-compact'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    }
  });
}
