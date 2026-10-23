import 'dart:convert';
import 'dart:math' as math;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/home_dismissible_reminders_section.dart';
import 'package:ascent/features/reminders/reminders_screen.dart';
import 'package:ascent/features/today/task_board_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Tasks & Today': true,
      'feature_guide_v1_Reminders & Alerts': true,
    });
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pumpAndSettle();
  }

  Future<void> mount(WidgetTester t, Widget child, {bool large = false}) async {
    if (large) {
      t.view.physicalSize = const Size(320, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
    }
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AscentTheme.dark(preset: DayThemePreset.merlotLinen),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
            child: child!,
          ),
          home: child,
        ),
      ),
    );
    await settle(t);
  }

  test(
    'AI creation results retain exact entity destinations in saved receipts',
    () async {
      final executor = RiyaExecutor(db);
      for (final command in [
        const RiyaCommand('tasks.create', {'title': 'Exact task'}),
        RiyaCommand('reminders.create', {
          'title': 'Exact reminder',
          'at': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        }),
        const RiyaCommand('thoughts.create', {'content': 'Exact thought'}),
      ]) {
        final result = await executor.execute(
          command,
          requestId: command.id,
          approved: true,
        );
        expect(result.entityId, isNotNull);
        expect(
          Uri.parse(result.targetRoute).queryParameters.values,
          contains('${result.entityId}'),
        );
        expect(result.toJson()['route'], result.targetRoute);
      }
    },
  );

  testWidgets(
    'compact task preview reveals a third task and has one board link',
    (t) async {
      for (var i = 1; i <= 3; i++) {
        await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Preview task $i',
            plannedDate: drift.Value(DateTime.now()),
          ),
        );
      }
      await mount(
        t,
        const Scaffold(
          body: SingleChildScrollView(child: ActivityHubCard(previewLimit: 2)),
        ),
      );
      expect(find.text('Preview task 3'), findsNothing);
      expect(find.text('Show 1 more'), findsOneWidget);
      expect(find.text('Open Board ›'), findsNothing);
      await t.ensureVisible(find.text('Show 1 more'));
      await t.tap(find.text('Show 1 more'));
      await settle(t);
      expect(find.text('Preview task 3'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    },
  );

  for (final kind in ['task', 'reminder']) {
    testWidgets('Riya View opens exact $kind details', (t) async {
      final id = kind == 'task'
          ? await db.taskDao.insertTask(
              TaskTableCompanion.insert(
                title: 'Exact future task',
                plannedDate: drift.Value(
                  DateTime.now().add(const Duration(days: 10)),
                ),
              ),
            )
          : await db.reminderDao.insertReminder(
              ReminderTableCompanion.insert(
                title: 'Exact future reminder',
                scheduledAt: DateTime.now().add(const Duration(days: 10)),
              ),
            );
      final route = kind == 'task'
          ? '/today?task=$id'
          : '/reminders?reminder=$id';
      await db.aiAssistantDao.insertMessage(
        AiChatMessageTableCompanion.insert(
          sender: 'assistant',
          message: 'Saved result',
          actionType: drift.Value('$kind.create'),
          actionPayloadJson: drift.Value(
            jsonEncode({
              'executionStatus': 'verified',
              'title': 'Saved',
              'route': route,
            }),
          ),
        ),
      );
      final router = GoRouter(
        initialLocation: '/ai',
        routes: [
          GoRoute(path: '/ai', builder: (_, _) => const AiAssistantScreen()),
          GoRoute(
            path: '/today',
            builder: (_, state) => TaskBoardScreen(
              initialTaskId: int.tryParse(
                state.uri.queryParameters['task'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/reminders',
            builder: (_, state) => RemindersScreen(
              initialReminderId: int.tryParse(
                state.uri.queryParameters['reminder'] ?? '',
              ),
            ),
          ),
        ],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AscentTheme.dark(preset: DayThemePreset.merlotLinen),
            routerConfig: router,
          ),
        ),
      );
      await settle(t);
      await t.tap(find.text('View'));
      await settle(t);
      expect(find.byType(Dialog), findsOneWidget);
      if (kind == 'reminder') {
        expect(find.text('REMINDER DETAILS'), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Exact future $kind'),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
      router.dispose();
    });
  }

  testWidgets(
    'chat clear requires confirmation and failures expose recovery at 320px 2x',
    (t) async {
      await db.aiAssistantDao.insertMessage(
        AiChatMessageTableCompanion.insert(
          sender: 'assistant',
          message: 'Failed request',
          actionPayloadJson: drift.Value(
            jsonEncode({'executionStatus': 'failed'}),
          ),
        ),
      );
      await mount(t, const AiAssistantScreen(), large: true);
      expect(find.text('Recover'), findsOneWidget);
      await t.tap(find.byTooltip('Clear chat history'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(
        await t.runAsync(() => db.aiAssistantDao.watchRecentMessages().first),
        hasLength(1),
      );
      await t.tap(find.byTooltip('Clear chat history'));
      await t.pumpAndSettle();
      await t.tap(find.text('Clear history'));
      await settle(t);
      expect(
        await t.runAsync(() => db.aiAssistantDao.watchRecentMessages().first),
        isEmpty,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('Home reminder actions fit 320px at 2x and meet 48dp targets', (
    t,
  ) async {
    final id = await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'A long reminder with inline actions',
        scheduledAt: DateTime.now(),
      ),
    );
    final row = (await db.reminderDao.getReminderById(id))!;
    await mount(
      t,
      Scaffold(
        body: SingleChildScrollView(
          child: HomeDismissibleRemindersSection(
            reminders: [row],
            onDismissReminder: (_) async {},
            onCompleteReminder: (_) async {},
            onSnoozeReminder: (_) async {},
          ),
        ),
      ),
      large: true,
    );
    for (final label in ['Mark done', 'Delete', 'Snooze 10 min']) {
      final size = t.getSize(find.byTooltip(label));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
  });

  test('all Merlot dark text and primary actions have readable contrast', () {
    final theme = AscentTheme.dark(preset: DayThemePreset.merlotLinen);
    double contrast(Color a, Color b) =>
        (math.max(a.computeLuminance(), b.computeLuminance()) + .05) /
        (math.min(a.computeLuminance(), b.computeLuminance()) + .05);
    final colors = theme.colorScheme;
    expect(
      contrast(colors.onSurface, colors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(contrast(colors.primary, colors.surface), greaterThanOrEqualTo(4.5));
    expect(
      contrast(colors.onPrimary, colors.primary),
      greaterThanOrEqualTo(4.5),
    );
  });
}
