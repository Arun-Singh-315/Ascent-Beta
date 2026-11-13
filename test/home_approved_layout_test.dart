import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/core/services/festival_service.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/daily_welcome_dialog.dart';
import 'package:ascent/features/home/widgets/home_life_shelf.dart';
import 'package:ascent/features/home/widgets/home_shortcut_icon.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Streak extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
    todaySeconds: 0,
    yesterdaySeconds: 0,
    priorStreakDays: 0,
    historicalLongestStreak: 0,
    historicalShortestStreak: 1,
    now: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  setUpAll(() async {
    await (FontLoader(
      'AscentZodiacSymbols',
    )..addFont(rootBundle.load('assets/fonts/AscentZodiacSymbols.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        todayFestivalProvider.overrideWithValue(null),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        studyStreakProvider.overrideWith(() => _Streak()),
        currentStreakStreamProvider.overrideWith((ref) => Stream.value(14)),
        homeStreakVisibleProvider.overrideWithValue(true),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  final profile = UserProfile(
    id: 1,
    name: 'Arun Singh',
    targetRole: '',
    targetCompanies: '[]',
    weeklyHoursAvailable: 10,
    preferredStudyWindow: 'morning',
    skillSelfRatings: '{}',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    onboardingComplete: true,
    dateOfBirth: DateTime(1998, 6, 10),
  );
  Widget app(
    Widget child, {
    bool dark = false,
    double scale = 1,
    GlobalKey? capture,
  }) => UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: HomeTheme.from(dark ? AscentTheme.dark() : AscentTheme.light()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
  }

  const output = String.fromEnvironment(
    'HOME_APPROVED_OUTPUT',
    defaultValue: '/tmp/ascent-approved-home',
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

  testWidgets(
    'All four day periods retain Rashi and streak with distinct scenes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final variant in [
        for (final dark in [false, true])
          for (final hour in [9, 14, 19, 23]) (dark: dark, hour: hour),
      ]) {
        final hour = variant.hour;
        final key = GlobalKey();
        await tester.pumpWidget(
          app(
            HomeHeader(profile: profile, now: DateTime(2026, 11, 7, hour)),
            dark: variant.dark,
            capture: key,
          ),
        );
        await settle(tester);
        expect(find.text('Gemini · Mithuna · Air'), findsOneWidget);
        expect(find.text('14 day streak'), findsOneWidget);
        expect(
          find.text(switch (hour) {
            9 => 'Good morning,',
            14 => 'Good afternoon,',
            19 => 'Good evening,',
            _ => 'Good night,',
          }),
          findsOneWidget,
        );
        expect(
          find.text(switch (hour) {
            9 => 'A little space to begin.',
            14 => 'Make room for a little reset.',
            19 => 'Close the day at your pace.',
            _ => 'Keep a little room for tomorrow.',
          }),
          findsOneWidget,
        );
        expect(
          find.byKey(
            ValueKey(
              'home_header_scene_${switch (hour) {
                9 => 'morning',
                14 => 'afternoon',
                19 => 'evening',
                _ => 'night',
              }}',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            ValueKey(
              'home_celestial_${switch (hour) {
                9 => 'morning',
                14 => 'afternoon',
                19 => 'evening',
                _ => 'night',
              }}',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(HomeHeader),
            matching: find.byType(Image),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          key,
          'header-$hour-${variant.dark ? 'dark' : 'light'}',
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
  testWidgets(
    'Home can reopen the daily brief without resetting daily popup history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = container.read(sharedPreferencesProvider);
      final seen = prefs.getString('ascent_daily_briefing_seen_v1');
      await tester.pumpWidget(app(HomeHeader(profile: profile)));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('home_daily_briefing')));
      await settle(tester);
      expect(find.byType(DailyWelcomeDialog), findsOneWidget);
      expect(prefs.getString('ascent_daily_briefing_seen_v1'), seen);
      await tester.tap(find.byTooltip('Dismiss daily briefing'));
      await settle(tester);
      expect(find.byType(DailyWelcomeDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Header supports narrow large text in both themes and omits unknown Rashi',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          app(
            HomeHeader(profile: profile, now: DateTime(2026, 11, 7, 19)),
            dark: dark,
            scale: 2,
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Profile and settings'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpWidget(
        app(HomeHeader(profile: null, now: DateTime(2026, 11, 7, 9))),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('home_rashi')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Rhythm shows every tool on the shared canvas with accessible actions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 1000);
          final key = GlobalKey();
          await tester.pumpWidget(
            app(
              const Padding(
                padding: EdgeInsets.all(20),
                child: HomeLifeShelf(),
              ),
              capture: key,
              dark: dark,
              scale: scale,
            ),
          );
          await settle(tester);
          final shelf = tester
              .getSize(find.byKey(const ValueKey('home_life_shelf')))
              .width;
          final water = find.byKey(const ValueKey('rhythm_card_hydration'));
          expect(tester.getSize(water).width, closeTo(shelf, .1));
          for (final id in [
            'hydration',
            'walk',
            'chai-break',
            'medicine',
            'momentum',
          ]) {
            expect(find.byKey(ValueKey('rhythm_select_$id')), findsOneWidget);
          }
          expect(
            find.byKey(const ValueKey('rhythm_peek_momentum')),
            findsNothing,
          );
          expect(find.byKey(const ValueKey('rhythm_peek_walk')), findsNothing);
          await capture(
            tester,
            key,
            'rhythm-${dark ? 'dark' : 'light'}-$scale',
          );
          await tester.tap(
            find.byKey(const ValueKey('home_routine_hydration')),
          );
          await settle(tester);
          expect(tester.getSize(water).width, closeTo(shelf, .1));
          expect(find.text('Add 250 ml'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            key,
            'rhythm-${dark ? 'dark' : 'light'}-$scale-expanded',
          );
          await tester.ensureVisible(find.byTooltip('Close details'));
          await tester.tap(find.byTooltip('Close details'));
          await settle(tester);
          for (final tool in ['walk', 'chai-break', 'medicine', 'momentum']) {
            await tester.ensureVisible(
              find.byKey(ValueKey('rhythm_select_$tool')),
            );
            await tester.tap(find.byKey(ValueKey('rhythm_select_$tool')));
            await settle(tester);
            expect(find.byKey(ValueKey('rhythm_card_$tool')), findsOneWidget);
            expect(
              find.byKey(const ValueKey('rhythm_card_hydration')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
            await capture(
              tester,
              key,
              'rhythm-$tool-${dark ? 'dark' : 'light'}-$scale',
            );
          }
          await tester.ensureVisible(
            find.byKey(const ValueKey('home_life_shelf')),
          );
          await tester.drag(
            find.byKey(const ValueKey('home_life_shelf')),
            const Offset(180, 0),
          );
          await settle(tester);
          expect(
            find.byKey(const ValueKey('rhythm_card_medicine')),
            findsOneWidget,
          );
          await tester.drag(
            find.byKey(const ValueKey('home_life_shelf')),
            const Offset(-180, 0),
          );
          await settle(tester);
          expect(
            find.byKey(const ValueKey('rhythm_card_momentum')),
            findsOneWidget,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('rhythm_select_hydration')),
          );
          await tester.tap(
            find.byKey(const ValueKey('rhythm_select_hydration')),
          );
          await settle(tester);
          expect(
            find.byKey(const ValueKey('rhythm_card_hydration')),
            findsOneWidget,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('rhythm_select_medicine')),
          );
          await tester.tap(
            find.byKey(const ValueKey('rhythm_select_medicine')),
          );
          await settle(tester);
          expect(
            find.byKey(const ValueKey('rhythm_card_medicine')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
  testWidgets(
    'Shortcut tiles stay neutral and reminder opens its actual destination',
    (tester) async {
      final reminder = Reminder(
        id: 73,
        title: 'Evening supplements',
        scheduledAt: DateTime.now().add(const Duration(hours: 3)),
        alarmEnabled: false,
        alertSyncPending: false,
        isActive: true,
        createdAt: DateTime.now(),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: HomeShortcutPanel(
                  showReminders: true,
                  reminders: [reminder],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/reminders',
            builder: (_, state) => Scaffold(
              body: Text('Opened ${state.uri.queryParameters['reminder']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: HomeTheme.from(AscentTheme.light()),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
      expect(find.byType(HomeShortcutIcon), findsNWidgets(4));
      for (final icon in find.byType(HomeShortcutIcon).evaluate()) {
        final box = find.descendant(
          of: find.byWidget(icon.widget),
          matching: find.byType(Container),
        );
        final decoration =
            tester.widget<Container>(box).decoration! as BoxDecoration;
        expect(decoration.color, isNot(Colors.transparent));
        expect(decoration.border, isNotNull);
      }
      expect(find.text('Evening supplements'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hub_reminder_73')));
      await settle(tester);
      expect(find.text('Opened 73'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
