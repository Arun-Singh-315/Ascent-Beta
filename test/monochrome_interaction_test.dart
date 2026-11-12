import 'package:ascent/shared/widgets/main_scaffold.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/monochrome_surfaces.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:ascent/shared/widgets/ascent_dialog.dart';
import 'package:ascent/shared/widgets/ascent_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets(
    'Large-text shell keeps all tab labels whole and leaves content reachable',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 780);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => MainScaffold(shell: shell),
            branches: [
              for (final name in ['home', 'reminders', 'vault', 'more'])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/$name',
                      builder: (_, _) => Scaffold(
                        body: ListView(
                          children: const [Text('Reachable content')],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AscentTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      for (final label in ['Home', 'Reminders', 'Vault', 'More']) {
        expect(find.text(label), findsOneWidget);
        expect(
          t.renderObject<RenderParagraph>(find.text(label)).didExceedMaxLines,
          isFalse,
          reason: label,
        );
      }
      expect(find.text('Reachable content'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.text('Reminders'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final dark in [false, true]) {
    testWidgets('Root dialog preserves invoking neutral theme, dark=$dark', (
      t,
    ) async {
      final base = dark ? AscentTheme.dark() : AscentTheme.light();
      await t.pumpWidget(
        MaterialApp(
          theme: base,
          home: Theme(
            data: HomeTheme.from(base),
            child: Builder(
              builder: (host) => Scaffold(
                body: TextButton(
                  child: const Text('Open overlay'),
                  onPressed: () => showAscentFrostedDialog<void>(
                    context: host,
                    builder: (_) =>
                        const Dialog(child: Text('Neutral overlay')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open overlay'));
      await t.pumpAndSettle();
      final overlay = t.element(find.text('Neutral overlay'));
      final neutral = Theme.of(overlay).extension<MonochromeSurfaces>();
      expect(neutral, isNotNull);
      expect(
        Theme.of(overlay).extension<AscentGlass>()!.elevated,
        neutral!.elevated,
      );
      expect(
        Theme.of(overlay).extension<AscentGlass>()!.surface,
        neutral.surface,
      );
      expect(base.extension<MonochromeSurfaces>(), isNull);
      Navigator.of(overlay).pop();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
      'Tinted action labels meet text contrast at rest and pressed, dark=$dark',
      (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: HomeTheme.from(
              dark ? AscentTheme.dark() : AscentTheme.light(),
            ),
            home: Scaffold(
              body: Center(
                child: AscentButton.primary(label: 'Save', onPressed: () {}),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        double contrast() {
          final text = t.widget<Text>(find.text('Save'));
          final foreground = text.style!.color!;
          final surface = find
              .ancestor(of: find.text('Save'), matching: find.byType(Container))
              .evaluate()
              .map((element) => element.widget as Container)
              .map((widget) => widget.decoration)
              .whereType<BoxDecoration>()
              .firstWhere((decoration) => decoration.color != null)
              .color!;
          final a = foreground.computeLuminance();
          final b = surface.computeLuminance();
          return ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
        }

        expect(contrast(), greaterThanOrEqualTo(4.5));
        final press = await t.startGesture(t.getCenter(find.text('Save')));
        await t.pump(const Duration(milliseconds: 200));
        expect(contrast(), greaterThanOrEqualTo(4.5));
        await press.up();
        await t.pumpAndSettle();
      },
    );
  }

  testWidgets(
    'Neutral navigation is usable at 200% without duplicating its trailing icon',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 780);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      var previous = 0;
      var next = 0;
      await t.pumpWidget(
        MaterialApp(
          theme: HomeTheme.from(AscentTheme.light()),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AscentButton.navigation(
                    label: 'Back',
                    icon: Icons.chevron_left,
                    onPressed: () => previous++,
                  ),
                  const Spacer(),
                  AscentButton.navigation(
                    label: 'Next',
                    icon: Icons.chevron_right,
                    iconAtEnd: true,
                    onPressed: () => next++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await t.tap(find.text('Back'));
      expect(next, 1);
      expect(previous, 1);
    },
  );

  testWidgets(
    'Restrained large-text segments wrap long labels and preserve selection',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 780);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      var selected = 'a';
      await t.pumpWidget(
        MaterialApp(
          theme: HomeTheme.from(AscentTheme.dark()),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, update) => AscentSegmentedControl<String>(
                  restrained: true,
                  segments: const [
                    AscentSegment(value: 'a', label: 'Overview of your day'),
                    AscentSegment(value: 'b', label: 'A quiet moment to reset'),
                  ],
                  selected: selected,
                  onChanged: (value) => update(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(FittedBox), findsNothing);
      await t.tap(find.text('A quiet moment to reset'));
      await t.pumpAndSettle();
      expect(selected, 'b');
      expect(t.takeException(), isNull);
    },
  );
}
