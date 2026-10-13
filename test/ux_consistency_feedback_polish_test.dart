import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';

class _MockDismissedNotifier extends DismissedTodayReminderIdsNotifier {
  @override
  Set<int> build() => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Switch / Toggle Global Theme Consistency', () {
    test(
      'AscentTheme defines unified switchTheme for light and dark modes',
      () {
        final lightTheme = AscentTheme.light();
        final darkTheme = AscentTheme.dark();

        expect(lightTheme.switchTheme, isNotNull);
        expect(darkTheme.switchTheme, isNotNull);

        // Verify thumb and track colors are specified and consistent
        final lightThumb = lightTheme.switchTheme.thumbColor?.resolve({
          WidgetState.selected,
        });
        final darkThumb = darkTheme.switchTheme.thumbColor?.resolve({
          WidgetState.selected,
        });

        expect(lightThumb, isNotNull);
        expect(darkThumb, isNotNull);

        final lightTrack = lightTheme.switchTheme.trackColor?.resolve({
          WidgetState.selected,
        });
        final darkTrack = darkTheme.switchTheme.trackColor?.resolve({
          WidgetState.selected,
        });

        expect(lightTrack, isNotNull);
        expect(darkTrack, isNotNull);
      },
    );
  });

  group('2. Today Activity Reminders Indicator', () {
    test('TodayActivityItem supports hasReminder flag with default false', () {
      const itemWithout = TodayActivityItem(
        id: 'task_1',
        title: 'Complete LeetCode',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        categoryTag: 'Task',
      );
      expect(itemWithout.hasReminder, isFalse);

      final itemWith = itemWithout.copyWith(hasReminder: true);
      expect(itemWith.hasReminder, isTrue);
    });
  });

  group('3. Home Visible Reminders Capping & Single Day Filtering', () {
    test(
      'homeVisibleRemindersProvider filters to only today or overdue today',
      () {
        final now = DateTime.now();
        final todayMorning = DateTime(now.year, now.month, now.day, 9, 0);
        final tomorrow = DateTime(now.year, now.month, now.day + 1, 10, 0);
        final nextWeek = DateTime(now.year, now.month, now.day + 7, 10, 0);

        final reminders = [
          Reminder(
            alarmEnabled: false,
            id: 1,
            title: 'Morning Standup',
            scheduledAt: todayMorning,
            isActive: true,
            createdAt: now,
            linkedTaskId: null,
            alertSyncPending: false,
          ),
          Reminder(
            alarmEnabled: false,
            id: 2,
            title: 'Tomorrow Review',
            scheduledAt: tomorrow,
            isActive: true,
            createdAt: now,
            linkedTaskId: null,
            alertSyncPending: false,
          ),
          Reminder(
            alarmEnabled: false,
            id: 3,
            title: 'Next Week Planning',
            scheduledAt: nextWeek,
            isActive: true,
            createdAt: now,
            linkedTaskId: null,
            alertSyncPending: false,
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            allRemindersProvider.overrideWithValue(AsyncValue.data(reminders)),
            dismissedTodayReminderIdsProvider.overrideWith(
              () => _MockDismissedNotifier(),
            ),
          ],
        );

        final visible = container.read(homeVisibleRemindersProvider);
        expect(visible.length, 1);
        expect(visible.first.id, 1);
        expect(visible.first.title, 'Morning Standup');
      },
    );
  });
}
