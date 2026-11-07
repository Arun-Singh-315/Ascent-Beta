import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/onboarding/onboarding_shell.dart';
import 'package:ascent/features/home/widgets/day_one_tutorial_card.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  late AppDatabase db;
  late SharedPreferences prefs;
  late ProviderContainer container;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  const output = String.fromEnvironment(
    'FIRST_RUN_OUTPUT',
    defaultValue: '/tmp/ascent-first-run',
  );
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final img =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      img.dispose();
    });
  }

  Widget wrap(
    Widget child, {
    double scale = 1,
    double keyboard = 0,
    GlobalKey? key,
  }) => UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AscentTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: child,
      ),
    ),
  );

  testWidgets(
    'Both welcome steps keep one next action visible at phone sizes and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(
          scale == 1 ? 390 : 320,
          scale == 1 ? 844 : 568,
        );
        container.read(onboardingProvider.notifier).setStep(0);
        final key = GlobalKey();
        await tester.pumpWidget(
          wrap(const OnboardingShell(), scale: scale, key: key),
        );
        await settle(tester);
        final next = find.byKey(const ValueKey('onboarding_next'));
        expect(next.hitTestable(), findsOneWidget);
        expect(find.text('Start now'), findsNothing);
        expect(find.text('Continue'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'welcome-$scale');
        await tester.tap(next);
        await settle(tester);
        expect(find.text('Open Ascent'), findsOneWidget);
        expect(next.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'personalize-$scale');
        await tester.runAsync(() async {
          expect(await db.select(db.taskTable).get(), isEmpty);
          expect(await db.thoughtDao.watchAllThoughts().first, isEmpty);
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    },
  );

  testWidgets('Name-free onboarding opens Home without seeding records', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingShell(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home ready')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AscentTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Continue'));
    await settle(tester);
    await tester.tap(find.text('Open Ascent'));
    await settle(tester);
    expect(find.text('Home ready'), findsOneWidget);
    expect(prefs.getBool('ascent_quick_start_v1'), isTrue);
    await tester.runAsync(() async {
      expect(await db.userProfileDao.getProfile(), isNull);
      expect(await db.select(db.taskTable).get(), isEmpty);
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'First welcome previews ideas without saving; explicit add saves exactly one real task',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    DayOneTutorialDialog.show(context, userName: 'Arun'),
                child: const Text('Show welcome'),
              ),
            ),
          ),
          key: key,
        ),
      );
      await tester.tap(find.text('Show welcome'));
      await settle(tester);
      await capture(tester, key, 'first-step-card');
      final save = find.byKey(const ValueKey('first_step_save'));
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.widget<AscentButton>(save).onPressed, isNull);
      await tester.runAsync(
        () async => expect(await db.select(db.taskTable).get(), isEmpty),
      );
      await tester.tap(find.text('Read a few pages'));
      await settle(tester);
      await tester.runAsync(
        () async => expect(await db.select(db.taskTable).get(), isEmpty),
      );
      await tester.enterText(
        find.byKey(const ValueKey('first_step_input')),
        'Read chapter one',
      );
      await tester.pump();
      await tester.tap(save);
      await settle(tester);
      expect(find.byType(DayOneTutorialDialog), findsNothing);
      await tester.runAsync(() async {
        final tasks = await db.select(db.taskTable).get();
        expect(tasks, hasLength(1));
        expect(tasks.single.title, 'Read chapter one');
      });
      expect(prefs.getBool(DayOneTutorialDialog.prefKey), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Welcome dismissal stays reachable with large text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    DayOneTutorialDialog.show(context, userName: ''),
                child: const Text('Show welcome'),
              ),
            ),
          ),
          scale: 2,
          keyboard: 280,
        ),
      );
      await tester.tap(find.text('Show welcome'));
      await settle(tester);
      expect(find.byTooltip('Explore on my own').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('first_step_save')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Explore on my own'));
      await settle(tester);
      await tester.runAsync(
        () async => expect(await db.select(db.taskTable).get(), isEmpty),
      );
      expect(find.byType(DayOneTutorialDialog), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
