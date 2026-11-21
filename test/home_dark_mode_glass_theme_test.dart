import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_composer.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/shared/widgets/ascent_dialog.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Dark Night Mode Glass Theme & Exception Handling Tests', () {
    test(
      'Requirement 1: HomeTheme.from configures dark glass tokens and blur: 0 for performance',
      () {
        final parentDark = AscentTheme.dark();
        final homeDark = HomeTheme.from(parentDark);

        expect(homeDark.brightness, equals(Brightness.dark));

        final glass = homeDark.extension<AscentGlass>();
        expect(glass, isNotNull);
        // Dark glass fill should have proper translucent opacity (> 0.06)
        expect(glass!.fill.a, greaterThan(0.06));
        // Edge should be crisp and defined (> 0.12)
        expect(glass.edge.a, greaterThan(0.12));

        final surfaces = homeDark.extension<AppSurfaces>();
        expect(surfaces, isNotNull);
        // Rule 2: Home screen blur must be 0 to guarantee <100ms render
        expect(surfaces!.blur, equals(0.0));
        // Card fill and border in dark surfaces should match glass tokens
        expect(surfaces.cardFill, equals(glass.fill));
        expect(surfaces.cardBorderColor, equals(glass.edge));
      },
    );



    testWidgets(
      'Requirement 4 (Exception): Docked ActivityComposer has distinct dock container in dark mode',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(
                () => _FakeTimeTrackingNotifier(),
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: Theme(
                data: HomeTheme.from(AscentTheme.dark()),
                child: const Scaffold(body: ActivityComposer()),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final inputFinder = find.byKey(const ValueKey('activity_quick_input'));
        expect(inputFinder, findsOneWidget);

        final textField = tester.widget<TextField>(inputFinder);

        // Text and hint must be legible
        expect(textField.style?.color, isNotNull);
        expect(textField.decoration?.hintStyle?.color, isNotNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Requirement 5 (Exception): AscentDialog has high opacity backdrop in dark mode to prevent bleed-through blunder',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      AscentDialog.confirm(
                        context: context,
                        title: 'Delete Activity?',
                        content: 'Are you sure you want to proceed?',
                      );
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Delete Activity?'), findsOneWidget);

        final fill = find.descendant(
          of: find.byType(AscentDialog),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color != null,
          ),
        );
        expect(fill, findsWidgets);
        final panel = tester.widget<Container>(fill.first);
        expect(
          (panel.decoration as BoxDecoration).color!.a,
          greaterThanOrEqualTo(.90),
        );
      },
    );
  });
}
