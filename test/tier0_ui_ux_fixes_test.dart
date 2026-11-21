import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/day_one_tutorial_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/providers/settings_provider.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Tier 0: DayOneTutorial emoji purge', () {
    testWidgets('DayOneTutorialCard buttons do not contain emojis', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(body: DayOneTutorialCard(userName: 'Alex')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('🚀'), findsNothing);
      expect(find.textContaining('👍'), findsNothing);
      expect(find.text('Choose your first small step'), findsOneWidget);
    });
  });

  group('Tier 0: ActivityRowItem Dismissible & Actions', () {
    testWidgets(
      'provides both background and secondaryBackground with zero reveal glitch',
      (tester) async {
        final item = TodayActivityItem(
          id: 'todo-1',
          title: 'Review System Architecture',
          status: TodayActivityStatus.notStarted,
          kind: ActivityKind.todo,
          sourceType: 'task',
          priority: 'high',
          categoryTag: 'work',
          elapsedSecondsToday: 0,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(activity: item, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dismissibleFinder = find.byType(Dismissible);
        expect(dismissibleFinder, findsOneWidget);

        final dismissible = tester.widget<Dismissible>(dismissibleFinder);
        expect(dismissible.background, isNotNull);
        expect(dismissible.secondaryBackground, isNotNull);
      },
    );

    testWidgets('untimed to-dos do not display play/pause timer buttons', (
      tester,
    ) async {
      final untimedTodo = TodayActivityItem(
        id: 'todo-untimed',
        title: 'Buy Groceries',
        status: TodayActivityStatus.notStarted,
        kind: ActivityKind.todo,
        sourceType: 'task',
        priority: 'normal',
        targetMinutes: null,
        categoryTag: 'personal',
        elapsedSecondsToday: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: ActivityRowItem(activity: untimedTodo, compact: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Untimed to-do has a check target, NOT a play button
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.timer_rounded), findsNothing);
    });
  });

  group(
    'Tier 0: StudyStreakMeterCard Honest Numbers & 320px Overflow Immunity',
    () {},
  );
}
