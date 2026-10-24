import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('Promise Card Visual Top-Middle Wrapper & Accessibility Tests', () {
    testWidgets('Home preview renders top-middle wrapper with PROMISE badge for promise thoughts', (tester) async {
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'No smoking today',
          mood: const drift.Value('promise'),
          category: const drift.Value('general'),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          allThoughtsStreamProvider.overrideWith(
            (ref) => Stream.value([
              Thought(
                id: 1,
                content: 'No smoking today',
                mood: 'promise',
                category: 'general',
                colorHex: '#2D2D3A',
                isPinned: false,
                isArchived: false,
                isCompleted: false,
                createdAt: DateTime.now(),
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find top-middle promise wrapper
      final promiseTagFinder = find.byKey(const ValueKey('promise_top_middle_wrapper_1'));
      expect(promiseTagFinder, findsOneWidget);
      expect(find.text('PROMISE'), findsWidgets);
    });

    testWidgets('Rule 13: Promise card layout renders with zero overflow at 320px width and 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          allThoughtsStreamProvider.overrideWith(
            (ref) => Stream.value([
              Thought(
                id: 1,
                content: 'Very long disciplined promise to test accessibility line wrapping across multiple lines defensively',
                mood: 'promise',
                category: 'general',
                colorHex: '#2D2D3A',
                isPinned: false,
                isArchived: false,
                isCompleted: false,
                createdAt: DateTime.now(),
              ),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified: No RenderFlex overflow exception
      expect(tester.takeException(), isNull);
    });
  });
}
