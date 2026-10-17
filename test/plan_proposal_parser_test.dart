import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/services/home_capture_service.dart';

void main() {
  group('HomeCaptureProposal Parsing for Routines & Recurring Plans', () {
    final now = DateTime(2026, 10, 17, 10, 0);

    test('Parses full proposal: Walk every morning at 7 for 30 minutes until 31 October. Remind me and keep asking whether I did it.', () {
      final input =
          'Walk every morning at 7 for 30 minutes until 31 October. Remind me and keep asking whether I did it.';
      final proposal = HomeCaptureProposal.parse(input, now);

      expect(proposal.scheduledIntent, isTrue);
      expect(proposal.isRecurring, isTrue);
      expect(proposal.recurrenceRule, 'daily');
      expect(proposal.localTime, '07:00');
      expect(proposal.minutes, 30);
      expect(proposal.endDate, '2026-10-31');
      expect(proposal.checkInPolicy, 'gentle');
      expect(proposal.followUp, isTrue);
      expect(proposal.title.toLowerCase().contains('walk'), isTrue);
      expect(proposal.needsEndClarification, isFalse);
    });

    test('Parses weekday routines: study math every weekday at 8:30 am until 2026-11-15 remind me', () {
      final input = 'study math every weekday at 8:30 am until 2026-11-15 remind me';
      final proposal = HomeCaptureProposal.parse(input, now);

      expect(proposal.scheduledIntent, isTrue);
      expect(proposal.isRecurring, isTrue);
      expect(proposal.recurrenceRule, 'weekdays');
      expect(proposal.localTime, '08:30');
      expect(proposal.endDate, '2026-11-15');
      expect(proposal.checkInPolicy, 'off'); // No follow-up requested
      expect(proposal.title.toLowerCase().contains('study math'), isTrue);
    });

    test('Flags missing end date when repetition is requested: practice guitar every day at 6 pm', () {
      final input = 'practice guitar every day at 6 pm';
      final proposal = HomeCaptureProposal.parse(input, now);

      expect(proposal.scheduledIntent, isTrue);
      expect(proposal.isRecurring, isTrue);
      expect(proposal.recurrenceRule, 'daily');
      expect(proposal.localTime, '18:00');
      expect(proposal.endDate, isNull);
      expect(proposal.needsEndClarification, isTrue);
    });

    test('Flags missing am/pm when ambiguous: workout every morning at 7', () {
      // "every morning at 7" -> morning indicates am!
      final morningInput = 'workout every morning at 7 until 31 October';
      final morningProposal = HomeCaptureProposal.parse(morningInput, now);
      expect(morningProposal.localTime, '07:00');
      expect(morningProposal.needsTimeClarification, isFalse);

      // "exercise every day at 7 until 31 October" (no am/pm and no morning/evening)
      final ambiguousInput = 'exercise every day at 7 until 31 October';
      final ambiguousProposal = HomeCaptureProposal.parse(ambiguousInput, now);
      expect(ambiguousProposal.needsTimeClarification, isTrue);
    });

    test('Parses simple one-time plan with Once policy and defaults', () {
      final input = 'remind me to call Mom tomorrow at 5 pm and check in';
      final proposal = HomeCaptureProposal.parse(input, now);

      expect(proposal.scheduledIntent, isTrue);
      expect(proposal.isRecurring, isFalse);
      expect(proposal.recurrenceRule, 'once');
      expect(proposal.checkInPolicy, 'once');
      expect(proposal.at?.day, 18);
      expect(proposal.at?.hour, 17);
      expect(proposal.at?.minute, 0);
    });

    test('Ordinary reflections stay ordinary thoughts without schedule intent', () {
      final input = 'I really enjoyed walking in the autumn breeze this morning.';
      final proposal = HomeCaptureProposal.parse(input, now);

      expect(proposal.scheduledIntent, isFalse);
      expect(proposal.isRecurring, isFalse);
      expect(proposal.at, isNull);
    });
  });
}
