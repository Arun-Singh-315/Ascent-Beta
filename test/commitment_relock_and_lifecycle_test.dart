import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/home_promise_section.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/promises/widgets/promise_card.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('UnlockedPromiseIdsNotifier Unit Tests', () {
    test('unlock, lock, toggle, and lockAll methods work correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(unlockedPromiseIdsProvider.notifier);
      expect(container.read(unlockedPromiseIdsProvider), isEmpty);

      // Unlock
      notifier.unlock(42);
      expect(container.read(unlockedPromiseIdsProvider), contains(42));

      notifier.unlock(99);
      expect(container.read(unlockedPromiseIdsProvider), equals({42, 99}));

      // Lock specific
      notifier.lock(42);
      expect(container.read(unlockedPromiseIdsProvider), equals({99}));

      // Toggle
      notifier.toggle(99);
      expect(container.read(unlockedPromiseIdsProvider), isEmpty);

      notifier.toggle(99);
      expect(container.read(unlockedPromiseIdsProvider), equals({99}));

      // Lock all
      notifier.unlock(101);
      expect(container.read(unlockedPromiseIdsProvider), equals({99, 101}));

      notifier.lockAll();
      expect(container.read(unlockedPromiseIdsProvider), isEmpty);
    });
  });

  group('Re-lock Tap & Menu Widget Tests', () {
    final samplePromise = PromiseModel(
      id: 7,
      title: 'Sacred Meditation',
      intention: 'Maintain daily mindfulness',
      category: 'spirituality',
      trackingType: PromiseTrackingType.completion,
      status: PromiseStatus.active,
      isPrivate: true,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    );

    testWidgets('Tapping unlocked lock icon on PromiseCard re-locks the promise', (tester) async {
      final container = ProviderContainer(
        overrides: [
          allPromisesStreamProvider.overrideWith((ref) => Stream.value([samplePromise])),
        ],
      );
      addTearDown(container.dispose);

      // Initially unlock promise #7
      container.read(unlockedPromiseIdsProvider.notifier).unlock(7);
      expect(container.read(unlockedPromiseIdsProvider), contains(7));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: PromiseCard(promise: samplePromise),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card is unlocked, shows LOCK action with lock_open_rounded
      final lockToggleFinder = find.byKey(const ValueKey('toggle_lock_promise_card_7'));
      expect(lockToggleFinder, findsOneWidget);
      expect(find.text('LOCK'), findsOneWidget);

      // Tap LOCK to re-lock
      await tester.tap(lockToggleFinder);
      await tester.pumpAndSettle();

      // Verified: Promise #7 is locked again
      expect(container.read(unlockedPromiseIdsProvider), isNot(contains(7)));
      expect(find.text('Private commitment'), findsOneWidget);
    });

    testWidgets('Selecting Lock commitment in popup menu re-locks the promise', (tester) async {
      final container = ProviderContainer(
        overrides: [
          allPromisesStreamProvider.overrideWith((ref) => Stream.value([samplePromise])),
        ],
      );
      addTearDown(container.dispose);

      // Unlock promise #7
      container.read(unlockedPromiseIdsProvider.notifier).unlock(7);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: PromiseCard(promise: samplePromise),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open popup menu
      final moreBtn = find.byIcon(Icons.more_horiz_rounded);
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // Tap "Lock commitment"
      final lockMenuItem = find.text('Lock commitment');
      expect(lockMenuItem, findsOneWidget);
      await tester.tap(lockMenuItem);
      await tester.pumpAndSettle();

      // Verified: Promise #7 is re-locked
      expect(container.read(unlockedPromiseIdsProvider), isNot(contains(7)));
      expect(find.text('Private commitment'), findsOneWidget);
    });

    testWidgets('Tapping UNLOCKED badge on Home Thought Preview re-locks the thought', (tester) async {
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Keep personal sacred promise',
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
                content: 'Keep personal sacred promise',
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
          privatePromiseIdsProvider.overrideWithValue({1}),
        ],
      );
      addTearDown(container.dispose);

      // Unlock thought #1
      container.read(unlockedPromiseIdsProvider.notifier).unlock(1);
      expect(container.read(unlockedPromiseIdsProvider), contains(1));

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

      // Find UNLOCKED • TAP TO LOCK badge
      final badgeFinder = find.byKey(const ValueKey('promise_top_middle_wrapper_1'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('UNLOCKED • TAP TO LOCK'), findsOneWidget);

      // Tap to re-lock
      await tester.tap(badgeFinder);
      await tester.pumpAndSettle();

      // Verified: ID 1 is removed from unlocked set and shows locked tile
      expect(container.read(unlockedPromiseIdsProvider), isNot(contains(1)));
      expect(find.text('Private commitment'), findsOneWidget);
    });

    testWidgets('Home Promise Section tap re-locks unlocked promise', (tester) async {
      final container = ProviderContainer(
        overrides: [
          allPromisesStreamProvider.overrideWith((ref) => Stream.value([samplePromise])),
          activePromisesStreamProvider.overrideWith((ref) => Stream.value([samplePromise])),
        ],
      );
      addTearDown(container.dispose);

      // Unlock
      container.read(unlockedPromiseIdsProvider.notifier).unlock(7);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: HomePromiseSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('toggle_lock_home_promise_7'));
      expect(toggleFinder, findsOneWidget);
      expect(find.text('LOCK'), findsOneWidget);

      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(container.read(unlockedPromiseIdsProvider), isNot(contains(7)));
      expect(find.text('Private commitment'), findsOneWidget);
    });
  });

  group('Rule 13: 320px width & 2.0x font scaling overflow safeguard', () {
    testWidgets('PromiseCard renders with zero RenderFlex overflow at 320px with 2.0x scale', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final samplePromise = PromiseModel(
        id: 12,
        title: 'Very long expansive promise title to test defensive scaling and zero overflows',
        intention: 'Continuous daily consistency with deep focus and mindfulness',
        category: 'personal_growth',
        trackingType: PromiseTrackingType.completion,
        status: PromiseStatus.active,
        isPrivate: true,
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          allPromisesStreamProvider.overrideWith((ref) => Stream.value([samplePromise])),
        ],
      );
      addTearDown(container.dispose);

      container.read(unlockedPromiseIdsProvider.notifier).unlock(12);

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
            home: Scaffold(
              body: SingleChildScrollView(
                child: PromiseCard(promise: samplePromise),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
