import 'package:shared_preferences/shared_preferences.dart';
import 'support/returning_user_guides.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';

void main() {
  late AppDatabase db;
  late ThoughtDao dao;

  setUp(() {
    SharedPreferences.setMockInitialValues(returningUserGuidePrefs);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = ThoughtDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Thought Wall Archiving & Done Status Logic Tests', () {
    test(
      'Active thoughts stream excludes archived thoughts and keeps pinned/newest order independent of completion',
      () async {
        final now = DateTime.now();

        // 1. Insert an active incomplete thought
        final id1 = await dao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Active thought 1',
            createdAt: drift.Value(now.subtract(const Duration(minutes: 10))),
          ),
        );

        // 2. Insert another active thought and mark it completed
        final id2 = await dao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Completed thought 2',
            createdAt: drift.Value(now.subtract(const Duration(minutes: 5))),
          ),
        );
        await dao.toggleCompleted(id2);

        // 3. Insert an archived thought
        final id3 = await dao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Archived thought 3',
            createdAt: drift.Value(now.subtract(const Duration(minutes: 2))),
          ),
        );
        await dao.archiveThought(id3);

        final active = await dao.watchActiveThoughts().first;
        expect(active.length, 2);
        expect(active.any((t) => t.id == id3), isFalse);

        // Completion does not reorder a note out of its chronological section.
        expect(active.first.id, id2);
        expect(active.first.isCompleted, isTrue);
        expect(active.last.id, id1);
        expect(active.last.isCompleted, isFalse);

        final archived = await dao.watchArchivedThoughts().first;
        expect(archived.length, 1);
        expect(archived.first.id, id3);
        expect(archived.first.isArchived, isTrue);
      },
    );

    test(
      'watchTodayThoughtsCount counts only today non-archived thoughts',
      () async {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));

        // Yesterday thought
        await dao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Yesterday reflection',
            createdAt: drift.Value(yesterday),
          ),
        );

        // Today thought 1
        await dao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Today reflection 1',
            createdAt: drift.Value(now),
          ),
        );

        // Today thought 2 (archived)
        final idArchived = await dao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Today archived',
            createdAt: drift.Value(now),
          ),
        );
        await dao.archiveThought(idArchived);

        // Today thought 3
        await dao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Today reflection 2',
            createdAt: drift.Value(now),
          ),
        );

        final count = await dao.watchTodayThoughtsCount().first;
        expect(count, 2);
      },
    );

    test('Unarchiving restores thought to active stream', () async {
      final id = await dao.insertThought(
        const ThoughtTableCompanion(
          content: drift.Value('Temporary archive test'),
        ),
      );

      await dao.archiveThought(id);
      var active = await dao.watchActiveThoughts().first;
      expect(active.isEmpty, isTrue);

      await dao.unarchiveThought(id);
      active = await dao.watchActiveThoughts().first;
      expect(active.length, 1);
      expect(active.first.isArchived, isFalse);
    });
  });

  group('Thought Wall Archive UI Integration Tests', () {
    testWidgets(
      'ThoughtWallScreen displays "All" date segment and archived badge',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Seed an archived thought
        final id = await dao.insertThought(
          const ThoughtTableCompanion(
            content: drift.Value('Deep personal reflection'),
            mood: drift.Value('me_to_me'),
          ),
        );
        await dao.archiveThought(id);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              thoughtDaoProvider.overrideWithValue(dao),
            ],
            child: const MaterialApp(home: ThoughtWallScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 1. Check segment header has "All"
        expect(find.text('All'), findsOneWidget);

        // 2. Switch to "All" tab
        await tester.tap(find.text('All'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // 3. Verify archived card is visible with ARCHIVED badge and 1-tap unarchive button
        expect(find.text('Deep personal reflection'), findsOneWidget);
        expect(find.text('ARCHIVED'), findsOneWidget);
        expect(find.byTooltip('Unarchive thought'), findsOneWidget);

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
