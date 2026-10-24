import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
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

  test('Creates and retrieves a promise with rich tracking attributes', () async {
    final promise = await repository.createPromise(
      title: 'Study Spring Boot for 45 mins',
      intention: 'I need to master microservices and become a strong backend dev.',
      category: 'study',
      trackingType: PromiseTrackingType.duration,
      targetValue: 45,
      unit: 'minutes',
      frequencyPerWeek: 5,
      isPrivate: false,
      reminderTime: '08:00',
    );

    expect(promise.id, isPositive);
    expect(promise.title, 'Study Spring Boot for 45 mins');
    expect(promise.trackingType, PromiseTrackingType.duration);
    expect(promise.targetValue, 45);

    final retrieved = await repository.getPromiseById(promise.id);
    expect(retrieved, isNotNull);
    expect(retrieved!.trackingType, PromiseTrackingType.duration);
    expect(retrieved.intention, contains('microservices'));
  });

  test('Records progress events and updates current values accurately', () async {
    final promise = await repository.createPromise(
      title: 'Workout at gym 4 times a week',
      intention: 'Build physical discipline',
      category: 'health',
      trackingType: PromiseTrackingType.frequency,
      targetValue: 4,
      unit: 'sessions',
      frequencyPerWeek: 4,
    );

    // Record 1st workout event
    await repository.recordProgress(
      promiseId: promise.id,
      eventType: PromiseEventType.frequencyCheckIn,
      amount: 1,
      note: 'Leg day completed',
    );

    var updated = (await repository.getPromiseById(promise.id))!;
    expect(updated.currentValue, 1);

    // Record 2nd workout event
    await repository.recordProgress(
      promiseId: promise.id,
      eventType: PromiseEventType.frequencyCheckIn,
      amount: 1,
      note: 'Chest and shoulders',
    );

    updated = (await repository.getPromiseById(promise.id))!;
    expect(updated.currentValue, 2);

    // Verify progress history events
    final events = await repository.getProgressEvents(promise.id);
    expect(events.length, 2);
    expect(events.first.note, 'Chest and shoulders');
  });

  test('Completing a promise marks status as completed and updates ThoughtTable', () async {
    final promise = await repository.createPromise(
      title: 'Call mom and dad',
      intention: 'Stay connected with family',
      category: 'relationships',
      trackingType: PromiseTrackingType.completion,
    );

    expect(promise.status, PromiseStatus.active);

    await repository.completePromise(promise.id);

    final updated = (await repository.getPromiseById(promise.id))!;
    expect(updated.status, PromiseStatus.completed);
    expect(updated.completedAt, isNotNull);

    // Verify corresponding ThoughtTable row is marked completed
    final thought = await db.thoughtDao.getThoughtById(promise.id);
    expect(thought, isNotNull);
    expect(thought!.isCompleted, isTrue);
  });

  test('Pausing and resuming a promise preserves all accumulated progress', () async {
    final promise = await repository.createPromise(
      title: 'Meditate 20 mins daily',
      intention: 'Inner calm',
      category: 'mindset',
      trackingType: PromiseTrackingType.duration,
      targetValue: 20,
    );

    await repository.recordProgress(
      promiseId: promise.id,
      eventType: PromiseEventType.durationSession,
      amount: 20,
    );

    // Pause
    await repository.setPromiseStatus(promise.id, PromiseStatus.paused);
    var p = (await repository.getPromiseById(promise.id))!;
    expect(p.status, PromiseStatus.paused);
    expect(p.currentValue, 20);

    // Resume
    await repository.setPromiseStatus(promise.id, PromiseStatus.active);
    p = (await repository.getPromiseById(promise.id))!;
    expect(p.status, PromiseStatus.active);
    expect(p.currentValue, 20);
  });
}
