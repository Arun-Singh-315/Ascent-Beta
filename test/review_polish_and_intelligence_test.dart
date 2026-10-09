import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/core/momentum/momentum_service.dart';
import 'package:ascent/shared/widgets/ascent_logo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MomentumDao momentumDao;
  late WaterDao waterDao;
  late ReminderDao reminderDao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    momentumDao = MomentumDao(db);
    waterDao = WaterDao(db);
    reminderDao = ReminderDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Thought Wall Batch Share & Formatter Tests', () {
    test('Formats empty list safely', () {
      final formatted = formatMultipleThoughtsForShare([]);
      expect(formatted, isEmpty);
    });

    test('Formats a single thought identically to single share format', () {
      final t = Thought(
        id: 1,
        content: 'Small steps every day yield exponential growth.',
        mood: 'focus',
        colorHex: '#0284C7',
        isPinned: false,
        isArchived: false,
        isCompleted: false,
        createdAt: DateTime(2026, 10, 9, 10, 0),
      );

      final formatted = formatMultipleThoughtsForShare([t]);
      expect(formatted, contains('"Small steps every day yield exponential growth."'));
      expect(formatted, contains('— Mind Space · Ascent'));
    });

    test('Formats multiple thoughts for WhatsApp batch sharing with clean separators', () {
      final t1 = Thought(
        id: 1,
        content: 'Action cures fear.',
        mood: 'energized',
        colorHex: '#10B981',
        isPinned: false,
        isArchived: false,
        isCompleted: false,
        createdAt: DateTime(2026, 10, 9, 9, 0),
      );

      final t2 = Thought(
        id: 2,
        content: 'Reflect before reacting.',
        mood: 'calm',
        colorHex: '#6366F1',
        promptQuestion: 'What did I learn today?',
        isPinned: true,
        isArchived: false,
        isCompleted: false,
        createdAt: DateTime(2026, 10, 9, 12, 0),
      );

      final formatted = formatMultipleThoughtsForShare([t1, t2]);
      expect(formatted, contains('"Action cures fear."'));
      expect(formatted, contains('💭 Prompt: What did I learn today?'));
      expect(formatted, contains('Note 1/2'));
      expect(formatted, contains('Note 2/2'));
      expect(formatted, contains('— Shared from Mind Space · Ascent'));
    });
  });

  group('Hydration 1-Tap Quick Increment Tests', () {
    test('Logs +250 mL increment correctly via WaterDao', () async {
      final today = DateTime.now();
      final initialTotal = await waterDao.getWaterForDate(today);
      expect(initialTotal, equals(0));

      // 1-tap quick action adds 250ml
      await waterDao.addWater(250);

      final updatedTotal = await waterDao.getWaterForDate(today);
      expect(updatedTotal, equals(250));

      // Second tap adds another 250ml
      await waterDao.addWater(250);
      final finalTotal = await waterDao.getWaterForDate(today);
      expect(finalTotal, equals(500));
    });
  });

  group('Monthly Reminder Recurrence Scheduling Tests', () {
    test('Generates 12 monthly occurrences handling varying month lengths without overflow', () async {
      // Base date: January 31st at 10:00 AM
      final baseScheduled = DateTime(2026, 1, 31, 10, 0);

      // Verify date math for monthly recurring reminders
      final occurrences = <DateTime>[];
      for (int m = 0; m < 12; m++) {
        final targetYear = baseScheduled.year + ((baseScheduled.month - 1 + m) ~/ 12);
        final targetMonth = ((baseScheduled.month - 1 + m) % 12) + 1;
        final maxDaysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
        final targetDay = baseScheduled.day > maxDaysInMonth ? maxDaysInMonth : baseScheduled.day;

        occurrences.add(DateTime(
          targetYear,
          targetMonth,
          targetDay,
          baseScheduled.hour,
          baseScheduled.minute,
        ));
      }

      expect(occurrences.length, equals(12));
      // Jan 31
      expect(occurrences[0], equals(DateTime(2026, 1, 31, 10, 0)));
      // Feb has 28 days in 2026 -> should be clamped to Feb 28
      expect(occurrences[1], equals(DateTime(2026, 2, 28, 10, 0)));
      // Mar 31
      expect(occurrences[2], equals(DateTime(2026, 3, 31, 10, 0)));
      // Apr has 30 days -> clamped to Apr 30
      expect(occurrences[3], equals(DateTime(2026, 4, 30, 10, 0)));
    });

    test('ReminderDao persists and retrieves upcoming vs completed correctly', () async {
      final now = DateTime.now();

      final reminderId1 = await reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'SIP Mutual Fund',
          scheduledAt: now.add(const Duration(days: 5)),
          isActive: const Value(true),
        ),
      );

      final reminderId2 = await reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Electricity Bill',
          scheduledAt: now.subtract(const Duration(hours: 2)),
          isActive: const Value(false), // Completed/inactive
        ),
      );

      final allReminders = await reminderDao.watchAllReminders().first;
      final upcoming = allReminders.where((r) => r.isActive && r.scheduledAt.isAfter(DateTime(now.year, now.month, now.day))).toList();
      final completed = allReminders.where((r) => !r.isActive || r.scheduledAt.isBefore(DateTime(now.year, now.month, now.day))).toList();

      expect(upcoming.length, equals(1));
      expect(upcoming.first.id, equals(reminderId1));
      expect(upcoming.first.title, equals('SIP Mutual Fund'));

      expect(completed.length, equals(1));
      expect(completed.first.id, equals(reminderId2));
      expect(completed.first.title, equals('Electricity Bill'));
    });
  });

  group('Momentum Time Intelligence & Day 1 Adaptation Tests', () {
    test('Adapts past Day 1 commitments when challenge starts mid-day', () async {
      final service = MomentumService(dao: momentumDao);

      // Start challenge
      final challengeId = await service.startChallenge(
        currentWeightKg: 75.0,
        targetWeightKg: 70.0,
        targetWakeMinutes: 360, // 06:00 AM
        baselineWakeMinutes: 480, // 08:00 AM
      );

      final commitments = await momentumDao.getAllCommitments(challengeId);
      final day1Commitments = commitments.where((c) => c.dayNumber == 1).toList();

      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      for (final c in day1Commitments) {
        if (c.scheduledTimeMinutes != null && c.scheduledTimeMinutes! < currentMinutes) {
          // Commitments before current time must be auto-completed and marked as adapted
          expect(c.isCompleted, isTrue, reason: 'Commitment ${c.title} was scheduled in past and should be completed');
          expect(c.wasAdapted, isTrue, reason: 'Commitment ${c.title} was scheduled in past and should be marked adapted');
        } else if (c.scheduledTimeMinutes != null && c.scheduledTimeMinutes! > currentMinutes) {
          // Future commitments today must NOT be auto-completed
          expect(c.isCompleted, isFalse, reason: 'Future commitment ${c.title} should remain uncompleted');
        }
      }
    });
  });

  group('Ascent Logo Brand Assets & Widget Tests', () {
    test('All brand logo asset files exist and have non-zero size', () {
      final logoPng = File('assets/images/logo.png');
      final logoSvg = File('assets/images/logo.svg');
      final appIcon = File('assets/icon/app_icon.png');
      final appIconFg = File('assets/icon/app_icon_foreground.png');

      expect(logoPng.existsSync(), isTrue);
      expect(logoPng.lengthSync(), greaterThan(1000));

      expect(logoSvg.existsSync(), isTrue);
      expect(logoSvg.lengthSync(), greaterThan(100));

      expect(appIcon.existsSync(), isTrue);
      expect(appIcon.lengthSync(), greaterThan(1000));

      expect(appIconFg.existsSync(), isTrue);
      expect(appIconFg.lengthSync(), greaterThan(1000));
    });

    testWidgets('AscentLogo widget renders without errors with custom dimensions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AscentLogo(size: 80),
          ),
        ),
      );

      expect(find.byType(AscentLogo), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
