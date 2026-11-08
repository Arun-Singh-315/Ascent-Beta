import 'dart:io';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/home_record_actions.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/splash/splash_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdleTracker extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets('calm actions use isolated memory data on the existing phone', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.taskDao.insertTask(
      TaskTableCompanion.insert(title: 'Make room for a quiet morning'),
    );
    final thoughtId = await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(
        content: 'One small step is enough for today.',
      ),
    );
    final reminderId = await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'Take a gentle pause',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
      ),
    );
    final reminder = (await db.reminderDao.getReminderById(reminderId))!;
    final activity = TodayActivityItem(
      id: 'task_$id',
      title: 'Make room for a quiet morning',
      kind: ActivityKind.todo,
      status: TodayActivityStatus.notStarted,
      sourceType: 'task',
      categoryTag: 'Task',
      elapsedSecondsToday: 0,
      linkedTaskId: id,
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(_IdleTracker.new),
      ],
    );
    var converted = false;
    Future<void> capture(String name) async {
      if (!converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
      }
      await t.pump();
      final bytes = await binding.takeScreenshot(name);
      await File(
        '${(await getTemporaryDirectory()).path}/calm-$name.png',
      ).writeAsBytes(bytes);
    }

    Future<void> flush() async {
      for (var i = 0; i < 10; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> hold(Finder finder) async {
      final gesture = await t.startGesture(t.getCenter(finder));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 900)),
      );
      await t.pump();
      await gesture.up();
      await flush();
    }

    Future<void> screen({bool dark = false, double scale = 1}) async {
      // Each appearance gets a fresh navigator and gesture state after modal tests.
      await t.pumpWidget(const SizedBox());
      await flush();
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? AscentTheme.dark() : AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ActivityRowItem(activity: activity, compact: true),
                      const SizedBox(height: 24),
                      const ThoughtWallHomePreview(
                        compact: true,
                        showComposer: false,
                      ),
                      Consumer(
                        builder: (context, ref, _) => TextButton(
                          onPressed: () =>
                              showHomeReminderActions(context, ref, reminder),
                          child: const Text('Reminder actions'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await flush();
    }

    await screen();
    await hold(find.text(activity.title));
    await flush();
    await t.pumpAndSettle();
    await capture('light-menu');
    await t.tap(find.text('Edit Activity'));
    await flush();
    expect(find.text('Edit this activity?'), findsOneWidget);
    await t.tap(find.text('Keep as is'));
    await flush();
    await t.pumpAndSettle();
    expect((await db.taskDao.getTaskById(id))!.title, activity.title);
    await t.tap(find.byIcon(Icons.more_horiz_rounded));
    await flush();
    await t.pumpAndSettle();
    await t.tap(find.text('Delete from Today'));
    await flush();
    await capture('delete-confirmation');
    await t.tap(find.text('Keep'));
    await flush();
    await t.pumpAndSettle();
    expect(await db.taskDao.getTaskById(id), isNotNull);

    await hold(find.text('One small step is enough for today.'));
    await flush();
    await t.pumpAndSettle();
    expect(find.text('Edit thought'), findsOneWidget);
    await t.tap(find.text('Delete thought'));
    await flush();
    await t.pumpAndSettle();
    await t.tap(find.text('Keep thought'));
    await flush();
    await t.pumpAndSettle();
    expect(await db.thoughtDao.getThoughtById(thoughtId), isNotNull);

    await t.tap(find.text('Reminder actions'));
    await flush();
    await t.pumpAndSettle();
    await t.tap(find.text('Edit reminder'));
    await flush();
    await t.enterText(find.byType(TextField), 'A little time to breathe');
    FocusManager.instance.primaryFocus?.unfocus();
    await flush();
    await t.pumpAndSettle();
    await t.tap(find.text('Save changes'));
    await flush();
    await t.pumpAndSettle();
    expect(find.text('Save these changes?'), findsOneWidget);
    await t.tap(find.text('Save changes').last);
    await flush();
    expect(
      (await db.reminderDao.getReminderById(reminderId))!.title,
      'A little time to breathe',
    );

    await screen(dark: true);
    await t.tap(find.byIcon(Icons.more_horiz_rounded));
    await flush();
    await t.pumpAndSettle();
    expect(find.text('Delete from Today'), findsOneWidget);
    await capture('dark-menu');
    await t.tap(find.byTooltip('Close actions'));
    await flush();
    await t.pumpAndSettle();
    await screen(scale: 2);
    await t.tap(find.byIcon(Icons.more_horiz_rounded));
    await flush();
    await t.pumpAndSettle();
    expect(find.text('Delete from Today'), findsOneWidget);
    await capture('large-text-menu');
    await t.ensureVisible(find.text('Delete from Today'));
    expect(t.takeException(), isNull);
    await t.tap(find.byTooltip('Close actions'));
    await flush();
    await t.pumpAndSettle();

    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const SplashScreen(),
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 900));
    await capture('splash');
    await t.pump(const Duration(seconds: 2));
    await t.pumpWidget(const SizedBox());
    await flush();
    await t.pumpAndSettle();
    container.dispose();
    await db.close();
  });
}
