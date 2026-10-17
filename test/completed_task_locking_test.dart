import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        dueCheckInForTaskProvider.overrideWith((ref, taskId) => Stream.value(null)),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Completed Activities & Tasks Locking Tests', () {
    testWidgets('Completed ActivityRowItem has DismissDirection.none (cannot swipe to delete)', (tester) async {
      const completedActivity = TodayActivityItem(
        id: 'task_1',
        title: 'Review System Architecture',
        status: TodayActivityStatus.done,
        sourceType: 'task',
        categoryTag: 'General',
        elapsedSecondsToday: 1800,
        targetMinutes: 30,
        linkedTaskId: 1,
      );

      await tester.pumpWidget(
        buildTestableWidget(const ActivityRowItem(activity: completedActivity)),
      );
      await tester.pump();

      final dismissibleFinder = find.byType(Dismissible);
      expect(dismissibleFinder, findsOneWidget);

      final dismissible = tester.widget<Dismissible>(dismissibleFinder);
      expect(dismissible.direction, DismissDirection.none);
    });

    testWidgets('Active ActivityRowItem allows swipe to delete (DismissDirection.endToStart)', (tester) async {
      const activeActivity = TodayActivityItem(
        id: 'task_2',
        title: 'Draft API Specification',
        status: TodayActivityStatus.notStarted,
        sourceType: 'task',
        categoryTag: 'General',
        elapsedSecondsToday: 0,
        targetMinutes: 45,
        linkedTaskId: 2,
      );

      await tester.pumpWidget(
        buildTestableWidget(const ActivityRowItem(activity: activeActivity)),
      );
      await tester.pump();

      final dismissibleFinder = find.byType(Dismissible);
      expect(dismissibleFinder, findsOneWidget);

      final dismissible = tester.widget<Dismissible>(dismissibleFinder);
      expect(dismissible.direction, DismissDirection.endToStart);
    });
  });
}
