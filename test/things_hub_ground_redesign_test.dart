import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'dart:async';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/shared_control_tokens.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/today/things_hub_screen.dart';
import 'package:ascent/features/today/widgets/things_interactive_card.dart';
import 'package:ascent/shared/widgets/glass_chip.dart';
import 'package:ascent/shared/widgets/ascent_segmented_control.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayActivityItem makeActivity({
  required String id,
  required String title,
  String? notes,
  ActivityKind kind = ActivityKind.todo,
  TodayActivityStatus status = TodayActivityStatus.notStarted,
  int? targetMinutes,
  String sourceType = 'task',
  String priority = 'normal',
  int? linkedTaskId,
  bool isOverdue = false,
  DateTime? scheduledTime,
}) => TodayActivityItem(
  id: id,
  title: title,
  notes: notes,
  kind: kind,
  status: status,
  sourceType: sourceType,
  categoryTag: 'Task',
  elapsedSecondsToday: 0,
  targetMinutes: targetMinutes,
  priority: priority,
  linkedTaskId: linkedTaskId,
  isOverdue: isOverdue,
  scheduledTime: scheduledTime,
);

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
    todaySeconds: 0,
    yesterdaySeconds: 0,
    priorStreakDays: 0,
    historicalLongestStreak: 0,
    historicalShortestStreak: 1,
    now: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpHub(
    WidgetTester tester,
    List<TodayActivityItem> items, {
    bool dark = false,
    double scale = 1,
    bool reduceMotion = false,
    String? initialTab,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(_FakeTimeTrackingNotifier.new),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          todayActivitiesProvider.overrideWith((ref) => Stream.value(items)),
        ],
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          ),
          home: RepaintBoundary(
            key: const ValueKey('things_qa'),
            child: ThingsHubScreen(initialTab: initialTab),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('HOME_SCREENSHOTS')) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('things_qa')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/things-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  setUpAll(() async {
    if (const bool.fromEnvironment('HOME_SCREENSHOTS')) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });

  List<TodayActivityItem> sampleThings() => [
    makeActivity(
      id: 'late',
      title: 'Send the signed documents',
      isOverdue: true,
    ),
    makeActivity(
      id: 'scheduled',
      title: 'Review the launch checklist',
      scheduledTime: DateTime.now().add(const Duration(hours: 1)),
    ),
    makeActivity(
      id: 'anytime',
      title: 'Book the weekend stay',
      priority: 'high',
    ),
    makeActivity(
      id: 'timer',
      title: 'Finish the project outline',
      status: TodayActivityStatus.paused,
      kind: ActivityKind.duration,
      targetMinutes: 25,
    ),
    makeActivity(
      id: 'done',
      title: 'Morning walk',
      status: TodayActivityStatus.done,
    ),
  ];

  for (final dark in [false, true]) {
    testWidgets(
      'One connected status board with colored headings and no toggle bars (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpHub(tester, sampleThings(), dark: dark);
        expect(find.byType(AscentSegmentedControl<String>), findsNothing);
        expect(find.byType(GlassChip), findsNothing);
        expect(
          find.byKey(const ValueKey('things_connected_card')),
          findsOneWidget,
        );
        expect(find.text('4 remaining · 1 completed'), findsOneWidget);
        expect(find.text('Send the signed documents'), findsOneWidget);
        expect(find.text('Review the launch checklist'), findsOneWidget);
        expect(find.text('Book the weekend stay'), findsOneWidget);
        expect(find.text('Finish the project outline'), findsOneWidget);
        final overdue = tester.widget<Text>(find.text('Overdue - 01'));
        final scheduled = tester.widget<Text>(find.text('Scheduled - 01'));
        expect(overdue.style!.color, SharedControlColors.dueRed);
        expect(
          scheduled.style!.color,
          dark
              ? SharedControlColors.actionBlueDark
              : SharedControlColors.actionBlue,
        );
        final headings = ['overdue', 'scheduled', 'anytime']
            .map(
              (s) => tester.getRect(find.byKey(ValueKey('things_heading_$s'))),
            )
            .toList();
        expect(headings[0].top, headings[1].top);
        expect(headings[1].top, headings[2].top);
        expect(find.text('Next'), findsNothing);
        await screenshot(tester, dark ? 'connected-dark' : 'connected-light');
        await tester.tap(
          find.byKey(const ValueKey('things_heading_scheduled')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Review the launch checklist'), findsOneWidget);
        expect(find.text('Send the signed documents'), findsNothing);
        expect(find.text('Book the weekend stay'), findsNothing);
        // A single selected heading does not repeat its title inside the content.
        expect(find.text('Scheduled today'), findsNothing);
        await screenshot(
          tester,
          dark ? 'connected-scheduled-dark' : 'connected-scheduled-light',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Headings replace the connected list, collapse on a second tap, and All restores everything',
    (tester) async {
      await pumpHub(tester, sampleThings());
      await tester.tap(find.byKey(const ValueKey('things_heading_overdue')));
      await tester.pumpAndSettle();
      expect(find.text('Send the signed documents'), findsOneWidget);
      expect(find.text('Book the weekend stay'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('things_heading_anytime')));
      await tester.pumpAndSettle();
      expect(find.text('Send the signed documents'), findsNothing);
      expect(find.text('Book the weekend stay'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('things_heading_anytime')));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityRowItem), findsNothing);
      expect(
        find.byKey(const ValueKey('things_heading_anytime')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('things_show_all')));
      await tester.pumpAndSettle();
      expect(find.text('Send the signed documents'), findsOneWidget);
      expect(find.text('4 remaining · 1 completed'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Book the weekend stay'),
        100,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('things_list_now')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Book the weekend stay'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Search keeps counts and lists in sync and closing it restores the board',
    (tester) async {
      await pumpHub(tester, sampleThings());
      await tester.tap(find.byTooltip('Search things'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'launch');
      await tester.pumpAndSettle();
      expect(find.text('Review the launch checklist'), findsOneWidget);
      expect(find.text('Send the signed documents'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('things_heading_scheduled')),
          matching: find.text('Scheduled - 01'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('things_heading_overdue')),
          matching: find.text('Overdue - 00'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.text('Send the signed documents'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Empty sections explain themselves and 1000 tasks remain lazy', (
    tester,
  ) async {
    await pumpHub(tester, [
      for (var i = 0; i < 1000; i++)
        makeActivity(id: 'task_$i', title: 'Flexible task $i'),
    ]);
    expect(find.byType(ActivityRowItem).evaluate().length, lessThan(25));
    await tester.tap(find.byKey(const ValueKey('things_heading_overdue')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing overdue'), findsOneWidget);
    expect(find.byType(ActivityRowItem), findsNothing);
    await tester.tap(find.text('Show all things'));
    await tester.pumpAndSettle();
    expect(find.text('Flexible task 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      '320px board keeps headings and actions readable at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await pumpHub(tester, sampleThings(), dark: true, scale: scale);
        await screenshot(
          tester,
          scale == 1 ? 'connected-320' : 'connected-large-text',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('things_heading_anytime')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('things_heading_anytime')));
        await tester.pumpAndSettle();
        final scrollable = find.descendant(
          of: find.byKey(const ValueKey('things_list_now')),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Resume'),
          120,
          scrollable: scrollable,
        );
        await tester.pumpAndSettle();
        await screenshot(
          tester,
          scale == 1
              ? 'connected-320-expanded'
              : 'connected-large-text-expanded',
        );
        expect(find.text('Resume'), findsOneWidget);
        if (scale == 2) {
          final title = find.byKey(const ValueKey('activity_title_timer'));
          expect(
            tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
            isFalse,
          );
          expect(tester.getSize(title).height, greaterThan(60));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Reduced motion and rapid section taps settle on the last heading',
    (tester) async {
      await pumpHub(tester, sampleThings(), reduceMotion: true);
      await tester.tap(find.byKey(const ValueKey('things_heading_overdue')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('things_heading_scheduled')));
      await tester.pump();
      expect(find.text('Review the launch checklist'), findsOneWidget);
      expect(find.text('Send the signed documents'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Completed view is available through the menu and deep links', (
    tester,
  ) async {
    await pumpHub(tester, sampleThings());
    await tester.tap(find.byTooltip('Things views'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('Morning walk'), findsOneWidget);
    expect(find.text('Book the weekend stay'), findsNothing);
    expect(find.byKey(const ValueKey('things_heading_overdue')), findsNothing);
    expect(find.text('Browse all history'), findsOneWidget);
    expect(find.byType(AscentSegmentedControl<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Board completion updates the real task and Undo restores it', (
    tester,
  ) async {
    final id = (await tester.runAsync(
      () => db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Send the proposal',
          plannedDate: Value(DateTime.now()),
        ),
      ),
    ))!;
    await pumpHub(tester, [
      makeActivity(
        id: 'complete',
        title: 'Send the proposal',
        linkedTaskId: id,
      ),
    ]);
    await tester.tap(find.byKey(const ValueKey('activity_action_complete')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
      (await tester.runAsync(
        () => db.taskDao.getTaskById(id),
      ))!.actualCompletedDate,
      isNotNull,
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(
      (await tester.runAsync(
        () => db.taskDao.getTaskById(id),
      ))!.actualCompletedDate,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Shared horizontal highlight matches unequal segment widths in both reading directions',
    (tester) async {
      for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
        var selected = 'all';
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(direction),
            theme: AscentTheme.light(),
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 288,
                    child: StatefulBuilder(
                      builder: (context, update) =>
                          AscentSegmentedControl<String>(
                            segments: const [
                              AscentSegment(
                                key: ValueKey('width_all'),
                                value: 'all',
                                label: 'All',
                                flex: 2,
                              ),
                              AscentSegment(
                                key: ValueKey('width_task'),
                                value: 'task',
                                label: 'To-dos',
                                flex: 3,
                              ),
                              AscentSegment(
                                key: ValueKey('width_timer'),
                                value: 'timer',
                                label: 'Timers',
                                flex: 3,
                              ),
                              AscentSegment(
                                key: ValueKey('width_medicine'),
                                value: 'medicine',
                                label: 'Medicines',
                                flex: 4,
                              ),
                            ],
                            selected: selected,
                            onChanged: (value) =>
                                update(() => selected = value),
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final value in ['all', 'task', 'timer', 'medicine']) {
          final segment = find.byKey(ValueKey('width_$value'));
          await tester.tap(segment);
          await tester.pumpAndSettle();
          final target = tester.getRect(segment);
          final highlight = tester.getRect(find.byType(AnimatedPositioned));
          expect(highlight.left, closeTo(target.left, .01));
          expect(highlight.width, closeTo(target.width, .01));
          expect(selected, value);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'ThingsInteractiveCard renders single ground border enclosure with no nested cards',
    (tester) async {
      final activity = makeActivity(
        id: 'act_ground_1',
        title: 'Review production pull request',
        linkedTaskId: 10,
        priority: 'high',
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ThingsInteractiveCard(activity: activity),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ground ActivityRowItem is rendered with ground style (no inner border/card)
      final rowFinder = find.byType(ActivityRowItem);
      expect(rowFinder, findsOneWidget);
      final rowWidget = tester.widget<ActivityRowItem>(rowFinder);
      expect(rowWidget.ground, isTrue);

      // Verify title is rendered prominently
      expect(find.text('Review production pull request'), findsOneWidget);

      // Verify Blueprint button exists
      expect(find.text('Blueprint'), findsOneWidget);

      // Tap Blueprint button to expand story micro-steps inline
      await tester.tap(find.text('Blueprint'));
      await tester.pumpAndSettle();

      expect(find.text('Hide'), findsOneWidget);
      expect(find.textContaining('Story Micro-Steps'), findsOneWidget);
    },
  );
}
