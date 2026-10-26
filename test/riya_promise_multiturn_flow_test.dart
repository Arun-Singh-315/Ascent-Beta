import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:ascent/core/ai/riya_intents.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/ai_assistant/riya_entity_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Riya Promise Multi-turn Details Flow', () {
    late AppDatabase db;
    late RiyaIntentResolver resolver;
    final now = DateTime(2026, 10, 26, 12);

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      resolver = RiyaIntentResolver(db, clock: () => now);
    });

    tearDown(() => db.close());

    test('step-by-step asks title -> target date / deadline -> reminder', () async {
      // 1. User says "New Promise"
      final r1 = await resolver.resolve('New Promise');
      expect(r1, isNotNull);
      expect(r1!.command, isNull);
      expect(r1.message, contains('Kis cheez ka Promise?'));

      // 2. User gives title only without deadline: "Read books"
      final r2 = await resolver.resolve('Read books');
      expect(r2, isNotNull);
      expect(r2!.command, isNull);
      expect(r2.message, contains('Yeh kab tak karna hai?'));
      expect(r2.options, contains('Daily / Roz'));
      expect(r2.options, contains('Next 30 days'));

      // 3. User specifies timeline: "Next 30 days"
      final r3 = await resolver.resolve('Next 30 days');
      expect(r3, isNotNull);
      expect(r3!.command, isNull);
      expect(r3.message, contains('Reminder kis time set karun?'));
      expect(r3.options, contains('8:00 AM'));
      expect(r3.options, contains('No reminder'));

      // 4. User specifies reminder: "subah 8 baje"
      final r4 = await resolver.resolve('subah 8 baje');
      expect(r4, isNotNull);
      expect(r4!.command, isNotNull);
      final cmd = r4.command!;
      expect(cmd.id, 'promises.create');
      final text = cmd.arguments['text'] as String;
      expect(text, contains('Read books'));
      expect(text, contains('30 days'));
      expect(text, contains('08:00'));
    });

    test('when timeline is provided upfront, Riya directly creates or asks reminder', () async {
      // User says: "Promise banao complete python course in 30 days"
      final r1 = await resolver.resolve('Promise banao complete python course in 30 days');
      expect(r1, isNotNull);
      expect(r1!.command, isNotNull);
      expect(r1.command!.id, 'promises.create');
      expect(r1.command!.arguments['text'], contains('30 days'));
    });

    test('when all details provided at once, resolves directly', () async {
      final r = await resolver.resolve('Promise banao walk daily at 7 AM reminder at 7 AM');
      expect(r, isNotNull);
      expect(r!.command, isNotNull);
      expect(r.command!.id, 'promises.create');
      expect(r.command!.arguments['text'], contains('walk daily'));
      expect(r.command!.arguments['text'], contains('7 AM'));
    });

    test('cancel aborts the conversational promise flow cleanly', () async {
      await resolver.resolve('New Promise');
      await resolver.resolve('Read 10 pages');
      final cancel = await resolver.resolve('Cancel');
      expect(cancel, isNotNull);
      expect(cancel!.message, contains('Cancelled. No changes were made.'));

      // Next statement should not be interpreted as a reminder response
      final next = await resolver.resolve('Show my tasks');
      expect(next?.command?.id, 'tasks.list');
    });
  });

  group('Riya Entity Card UI Details & Contrast', () {
    testWidgets('renders target date and reminder with high-contrast text and icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: RiyaEntityCard.buildPane(
                  context,
                  'Master Flutter Architecture',
                  type: 'promises',
                  targetDate: '26 Nov 2026',
                  reminder: '08:00 AM',
                  category: 'Learning',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title is rendered
      expect(find.text('Master Flutter Architecture'), findsOneWidget);

      // Verify target date text and calendar icon
      expect(find.text('Target: 26 Nov 2026'), findsOneWidget);
      expect(find.byIcon(Icons.event_outlined), findsOneWidget);

      // Verify reminder text and notifications icon
      expect(find.text('Reminder: 08:00 AM'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);

      // Verify category chip is rendered
      expect(find.text('PROMISE · LEARNING'), findsOneWidget);

      // Verify text styling contrast (non-null and bold/medium weights)
      final targetWidget = tester.widget<Text>(find.text('Target: 26 Nov 2026'));
      expect(targetWidget.style?.fontWeight, FontWeight.w600);
      expect(targetWidget.style?.color, isNotNull);

      final reminderWidget = tester.widget<Text>(find.text('Reminder: 08:00 AM'));
      expect(reminderWidget.style?.fontWeight, FontWeight.w500);
      expect(reminderWidget.style?.color, isNotNull);
    });
  });
}
