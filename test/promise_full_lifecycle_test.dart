import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/services/promise_intent_parser.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PromiseRepository repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = PromiseRepository(db);
    await repository.initialize();
  });

  tearDown(() async {
    await db.close();
  });

  group('Promise Full Lifecycle & Privacy Specification', () {
    test('User journey: Draft -> Natural Language Adjustment -> Create -> Track -> Complete', () async {
      // 1. Initial conversational statement
      var proposal = PromiseIntentParser.parse('I need to study Spring Boot for 45 minutes every day');
      expect(proposal.targetValue, 45);
      expect(proposal.trackingType, PromiseTrackingType.duration);

      // 2. Natural language adjustment: "Make it 30 minutes and keep this private"
      proposal = PromiseIntentParser.applyAdjustment(proposal, 'Make it 30 minutes');
      expect(proposal.targetValue, 30);
      proposal = PromiseIntentParser.applyAdjustment(proposal, 'Keep this private');
      expect(proposal.isPrivate, isTrue);

      // 3. Create promise in repository
      final promise = await repository.createPromise(
        title: proposal.title,
        intention: proposal.intention,
        category: proposal.category,
        trackingType: proposal.trackingType,
        targetValue: proposal.targetValue,
        unit: proposal.unit,
        frequencyPerWeek: proposal.frequencyPerWeek,
        isPrivate: proposal.isPrivate,
        reminderTime: proposal.reminderTime,
      );

      expect(promise.id, isPositive);
      expect(promise.isPrivate, isTrue);
      expect(promise.targetValue, 30);
      expect(promise.currentValue, 0);

      // 4. Record 15-minute practice session
      await repository.recordProgress(
        promiseId: promise.id,
        eventType: PromiseEventType.durationSession,
        amount: 15,
        note: 'Completed Chapter 1 and controllers',
      );

      var p = (await repository.getPromiseById(promise.id))!;
      expect(p.currentValue, 15);
      expect(p.progressFraction, 0.5);
      expect(p.isCompleted, isFalse);

      // 5. Record another 15-minute practice session
      await repository.recordProgress(
        promiseId: promise.id,
        eventType: PromiseEventType.durationSession,
        amount: 15,
        note: 'Implemented repositories and service layer',
      );

      p = (await repository.getPromiseById(promise.id))!;
      expect(p.currentValue, 30);
      expect(p.progressFraction, 1.0);

      // 6. Complete promise
      await repository.completePromise(promise.id);
      p = (await repository.getPromiseById(promise.id))!;
      expect(p.isCompleted, isTrue);
      expect(p.completedAt, isNotNull);

      // 7. Verify all history events preserved
      final events = await repository.getProgressEvents(promise.id);
      expect(events.length, 2);
      expect(events[1].note, contains('Chapter 1'));
      expect(events[0].note, contains('repositories'));
    });

    test('Pausing a promise preserves accumulated history and allows clean resume', () async {
      final promise = await repository.createPromise(
        title: 'Run 5km 3 times a week',
        intention: 'Cardio fitness',
        category: 'health',
        trackingType: PromiseTrackingType.frequency,
        targetValue: 3,
        frequencyPerWeek: 3,
      );

      await repository.recordProgress(
        promiseId: promise.id,
        eventType: PromiseEventType.frequencyCheckIn,
        amount: 1,
        note: 'Morning run 5.2km',
      );

      // Pause
      await repository.setPromiseStatus(promise.id, PromiseStatus.paused);
      var p = (await repository.getPromiseById(promise.id))!;
      expect(p.isPaused, isTrue);
      expect(p.currentValue, 1);

      // Active promises query should NOT include paused promise
      final active = await repository.getActivePromises();
      expect(active.any((item) => item.id == promise.id), isFalse);

      // Paused promises query SHOULD include paused promise
      final paused = await repository.getPausedPromises();
      expect(paused.any((item) => item.id == promise.id), isTrue);

      // Resume
      await repository.setPromiseStatus(promise.id, PromiseStatus.active);
      p = (await repository.getPromiseById(promise.id))!;
      expect(p.isActive, isTrue);
      expect(p.currentValue, 1);
    });

    test('Deleting a promise cascades cleanly removing metadata and events', () async {
      final promise = await repository.createPromise(
        title: 'Meditate',
        intention: 'Mindfulness',
        category: 'wellness',
        trackingType: PromiseTrackingType.reflection,
      );

      await repository.recordProgress(
        promiseId: promise.id,
        eventType: PromiseEventType.reflectionNote,
        amount: 1,
        note: 'Peaceful morning',
      );

      await repository.deletePromise(promise.id);

      final retrieved = await repository.getPromiseById(promise.id);
      expect(retrieved, isNull);

      final events = await repository.getProgressEvents(promise.id);
      expect(events, isEmpty);
    });
  });
}
