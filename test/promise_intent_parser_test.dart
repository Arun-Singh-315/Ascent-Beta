import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/services/promise_intent_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PromiseIntentParser - Natural Language Understanding', () {
    test('parses duration-based study commitment', () {
      final parsed = PromiseIntentParser.parse(
        'I need to study Spring Boot for 45 minutes every day',
      );

      expect(parsed.title, contains('Study Spring Boot'));
      expect(parsed.trackingType, PromiseTrackingType.duration);
      expect(parsed.targetValue, 45);
      expect(parsed.unit, 'minutes');
      expect(parsed.category, 'study');
    });

    test('parses frequency-based gym commitment', () {
      final parsed = PromiseIntentParser.parse(
        'I want to go to the gym 4 times a week',
      );

      expect(parsed.title, 'Go to the gym 4 times a week');
      expect(parsed.trackingType, PromiseTrackingType.frequency);
      expect(parsed.frequencyPerWeek, 4);
      expect(parsed.category, 'health');
    });

    test('parses one-time / recurring completion commitment', () {
      final parsed = PromiseIntentParser.parse(
        'I promise to call my parents every Sunday',
      );

      expect(parsed.title, contains('Call my parents'));
      expect(parsed.trackingType, PromiseTrackingType.completion);
      expect(parsed.category, 'relationships');
    });

    test('parses milestone target-date commitment', () {
      final parsed = PromiseIntentParser.parse(
        'I want to finish this course by the end of November',
      );

      expect(parsed.trackingType, PromiseTrackingType.milestone);
      expect(parsed.title, contains('Finish'));
      expect(parsed.targetDate, isNotNull);
    });

    test('parses behavioral reflection commitment', () {
      final parsed = PromiseIntentParser.parse(
        'I want to stop wasting time scrolling at night',
      );

      expect(parsed.trackingType, PromiseTrackingType.reflection);
      expect(parsed.category, 'wellness');
    });

    test('detects privacy preference in natural language', () {
      final parsed = PromiseIntentParser.parse(
        'I want to meditate for 15 minutes, keep this private',
      );

      expect(parsed.isPrivate, isTrue);
      expect(parsed.trackingType, PromiseTrackingType.duration);
      expect(parsed.targetValue, 15);
    });

    test('handles natural language adjustments on proposal', () {
      var proposal = PromiseIntentParser.parse(
        'I want to study Java for 45 minutes',
      );
      expect(proposal.targetValue, 45);

      // User says "Make it 30 minutes"
      proposal = PromiseIntentParser.applyAdjustment(
        proposal,
        'Make it 30 minutes',
      );
      expect(proposal.targetValue, 30);

      // User says "Only on weekdays"
      proposal = PromiseIntentParser.applyAdjustment(
        proposal,
        'Only on weekdays',
      );
      expect(proposal.reminderDays, [1, 2, 3, 4, 5]);

      // User says "Keep this private"
      proposal = PromiseIntentParser.applyAdjustment(
        proposal,
        'Keep this private',
      );
      expect(proposal.isPrivate, isTrue);
    });
  });
}
