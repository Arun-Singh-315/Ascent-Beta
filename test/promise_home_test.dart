import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_promise_section.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
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

  testWidgets(
    'HomePromiseSection displays priority commitment and executes 1-tap action',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final promise = (await tester.runAsync(
        () => repository.createPromise(
          title: 'Call mom and dad',
          intention: 'Family connection',
          category: 'relationships',
          trackingType: PromiseTrackingType.completion,
        ),
      ))!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            promiseRepositoryProvider.overrideWithValue(repository),
            activePromisesStreamProvider.overrideWith(
              (ref) => Stream.value([promise]),
            ),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: HomePromiseSection()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify section heading
      expect(find.text('Promises'), findsOneWidget);

      // Verify promise title
      expect(find.text('Call mom and dad'), findsOneWidget);

      // Verify contextual 1-tap action
      final actionBtn = find.byKey(
        const ValueKey('home_promise_primary_action'),
      );
      expect(actionBtn, findsOneWidget);
      expect(find.text('Mark Completed'), findsOneWidget);

      // Execute 1-tap action directly from Home
      await tester.tap(actionBtn);
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      final updated = await tester.runAsync(
        () => repository.getPromiseById(promise.id),
      );
      expect(updated!.status, PromiseStatus.completed);
    },
  );

  testWidgets(
    'HomePromiseSection renders cleanly without overflow at 320px with 2.0x text scale',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      tester.view.physicalSize = const Size(320 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final promise = (await tester.runAsync(
        () => repository.createPromise(
          title: 'Study Spring Boot and Cloud Microservices for 45 mins',
          intention:
              'Master complex distributed architecture with daily discipline',
          category: 'study',
          trackingType: PromiseTrackingType.duration,
          targetValue: 45,
          unit: 'minutes',
          currentValue: 15,
        ),
      ))!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            promiseRepositoryProvider.overrideWithValue(repository),
            activePromisesStreamProvider.overrideWith(
              (ref) => Stream.value([promise]),
            ),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(child: HomePromiseSection()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Zero RenderFlex overflows under 320px + 2.0x scale (Rule 13)
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('home_promise_card')), findsOneWidget);
    },
  );
}
