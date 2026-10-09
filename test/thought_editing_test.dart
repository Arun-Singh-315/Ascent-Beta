import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late ThoughtDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ThoughtDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Thought Editing Tests in Mind Space', () {
    test('updateThought edits content and mood successfully without changing creation date', () async {
      final initialDate = DateTime.now().subtract(const Duration(hours: 3));

      // 1. Insert original thought
      final id = await dao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'I made a typo in this thought: 60% progress is good',
          mood: const drift.Value('thought'),
          isPinned: const drift.Value(false),
          createdAt: drift.Value(initialDate),
        ),
      );

      final original = await dao.getThoughtById(id);
      expect(original, isNotNull);
      expect(original!.content, contains('I made a typo in this thought'));
      expect(original.mood, 'thought');

      // 2. Update thought with corrected content and mood
      final updatedCompanion = original.toCompanion(true).copyWith(
        content: const drift.Value('Corrected reflection: Steady daily pace achieved!'),
        mood: const drift.Value('win'),
        isPinned: const drift.Value(true),
      );

      final success = await dao.updateThought(updatedCompanion);
      expect(success, isTrue);

      // 3. Verify changes persisted
      final updated = await dao.getThoughtById(id);
      expect(updated, isNotNull);
      expect(updated!.content, 'Corrected reflection: Steady daily pace achieved!');
      expect(updated.mood, 'win');
      expect(updated.isPinned, isTrue);
      expect(updated.createdAt.millisecondsSinceEpoch ~/ 1000, initialDate.millisecondsSinceEpoch ~/ 1000);
    });
  });
}
