import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/features/feature_registry.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/onboarding/onboarding_shell.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<(AppDatabase, SharedPreferences)> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingShell(),
        ),
        GoRoute(path: '/home', builder: (_, _) => const Text('home page')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return (db, prefs);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Skip goes straight in with defaults', (tester) async {
    final (_, prefs) = await pump(tester);
    expect(find.text('Your day,\ncalmly in one place.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding_skip')));
    await settle(tester);
    expect(find.text('home page'), findsOneWidget);
    expect(prefs.getBool('ascent_quick_start_v1'), isTrue);
    expect(prefs.getStringList(unlockedFeaturesKey), ['things', 'mind']);
    await done(tester);
  });

  testWidgets('three screens: name saved, mode set, first features picked', (
    tester,
  ) async {
    final (db, prefs) = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('onboarding_next')));
    await settle(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('onboarding_name')),
        matching: find.byType(EditableText),
      ),
      'arun singh',
    );
    await tester.pump();
    expect(find.textContaining('Arun singh.'), findsOneWidget);
    final dark = find.text('Dark');
    await tester.ensureVisible(dark);
    await tester.tap(dark);
    await tester.pump();
    expect(prefs.getString('ascent_theme_mode'), contains('dark'));
    await tester.tap(find.byKey(const ValueKey('onboarding_next')));
    await settle(tester);

    // Plan + Thoughts start selected; swap Thoughts for Care.
    expect(find.text('Start with these two'), findsOneWidget);
    for (final key in ['onboarding_pick_mind', 'onboarding_pick_care']) {
      final f = find.byKey(ValueKey(key));
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('onboarding_next')));
    await settle(tester);
    expect(find.text('home page'), findsOneWidget);
    expect(prefs.getStringList(unlockedFeaturesKey), ['things', 'care']);
    final profile = await tester.runAsync(() => db.userProfileDao.getProfile());
    expect(profile!.name, 'Arun Singh');
    await done(tester);
  });

  for (final dark in [false, true]) {
    testWidgets('fits 320 px at 2.0x text (dark=$dark)', (tester) async {
      await pump(tester, size: const Size(320, 640), scale: 2);
      expect(tester.takeException(), isNull);
      await done(tester);
    });
  }
}
