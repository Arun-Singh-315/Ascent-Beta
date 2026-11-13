import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/daily_briefing_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/daily_welcome_service.dart';
import 'package:ascent/features/home/widgets/daily_welcome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

DailyBriefing _briefing({
  int completed = 0,
  int minutes = 0,
  int due = 0,
  int overdue = 0,
  String? next,
}) => DailyBriefing(
  completedYesterday: completed,
  plannedYesterday: 0,
  finishedPlannedYesterday: 0,
  trackedMinutesYesterday: minutes,
  dueToday: due,
  overdue: overdue,
  unscheduled: 0,
  nextTask: next,
);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('when the daily welcome opens', () {
    final now = DateTime(2026, 11, 3, 9, 30);
    Future<SharedPreferences> prefsWith(Map<String, Object> v) async {
      SharedPreferences.setMockInitialValues(v);
      return SharedPreferences.getInstance();
    }

    test('first open ever, and first open on a new day, show it', () async {
      var prefs = await prefsWith({});
      expect(
        shouldShowDailyWelcome(prefs: prefs, now: now, autoOpen: true),
        isTrue,
      );
      prefs = await prefsWith({
        dailyWelcomeSeenKey: DateTime(2026, 11, 2).toIso8601String(),
      });
      expect(
        shouldShowDailyWelcome(prefs: prefs, now: now, autoOpen: true),
        isTrue,
      );
    });

    test('never twice on the same day, even late at night', () async {
      final prefs = await prefsWith({});
      await markDailyWelcomeSeen(prefs, now);
      expect(
        shouldShowDailyWelcome(prefs: prefs, now: now, autoOpen: true),
        isFalse,
      );
      expect(
        shouldShowDailyWelcome(
          prefs: prefs,
          now: DateTime(2026, 11, 3, 23, 59),
          autoOpen: true,
        ),
        isFalse,
      );
      expect(
        shouldShowDailyWelcome(
          prefs: prefs,
          now: DateTime(2026, 11, 4, 0, 1),
          autoOpen: true,
        ),
        isTrue,
      );
    });

    test('respects the setting and a clock that moved back', () async {
      final prefs = await prefsWith({
        dailyWelcomeSeenKey: DateTime(2026, 11, 9).toIso8601String(),
      });
      expect(
        shouldShowDailyWelcome(prefs: prefs, now: now, autoOpen: true),
        isFalse,
      );
      final fresh = await prefsWith({});
      expect(
        shouldShowDailyWelcome(prefs: fresh, now: now, autoOpen: false),
        isFalse,
      );
    });
  });

  group('written summary', () {
    test('describes progress in words and never says zero', () {
      final b = _briefing(
        completed: 4,
        minutes: 80,
        due: 2,
        overdue: 1,
        next: 'Send proposal',
      );
      expect(
        b.yesterdayStory,
        'Yesterday you finished 4 tasks and spent 1h 20m in focus.',
      );
      expect(
        b.todayStory,
        'You have 2 things due today and 1 task carried over. A good place to begin: “Send proposal”.',
      );
    });

    test('empty days get a kind sentence, not 0 counters', () {
      final b = _briefing();
      expect(b.yesterdayStory, isNot(contains('0')));
      expect(b.todayStory, isNot(contains('0')));
      expect(b.todayStory, contains('wide open'));
    });

    test('singular forms read naturally', () {
      final b = _briefing(completed: 1, due: 1);
      expect(b.yesterdayStory, 'Yesterday you finished 1 task.');
      expect(b.todayStory, 'You have 1 thing due today.');
    });
  });

  testWidgets('centred card with swipeable pages and a close button', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final day = DateTime(2026, 11, 3);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dailyBriefingProvider.overrideWith(
            (ref, d) async =>
                _briefing(completed: 2, due: 1, next: 'Write report'),
          ),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    DailyWelcomeDialog.show(ctx, day: day, name: 'Arun Singh'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Arun.'), findsOneWidget);
    expect(find.text('Tasks due today'), findsOneWidget);

    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Write report'), findsOneWidget);

    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Capture something'), findsOneWidget);
    expect(find.text('Yesterday you finished 2 tasks.'), findsOneWidget);

    await t.tap(find.byTooltip('Dismiss daily briefing'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(DailyWelcomeDialog), findsNothing);
  });
}
