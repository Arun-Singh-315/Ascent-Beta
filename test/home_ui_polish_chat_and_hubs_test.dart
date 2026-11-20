import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/frozen_palette.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
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

  group('Home UI Polish: Chat & Hubs Requirements Tests', () {
    testWidgets(
      'Demand 1: ThoughtWallHomePreview send button dynamically resolves to theme clay color',
      (tester) async {
        // Mount with Classic Clay (Warm terracotta: #A4523A)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              recentThoughtsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(preset: DayThemePreset.classicClay),
              home: const Scaffold(body: ThoughtWallHomePreview()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iconFinder = find.byIcon(Icons.arrow_upward_rounded);
        expect(iconFinder, findsOneWidget);
        final buttonFinder = find.ancestor(
          of: iconFinder,
          matching: find.byType(IconButton),
        );
        final buttonWidget = tester.widget<IconButton>(buttonFinder);
        final bg = buttonWidget.style?.backgroundColor?.resolve({});
        // In Classic Clay, bg must be clay (#A4523A), NOT FrozenPalette.action (blue)
        expect(bg, AscentGlass.light.clay);
        expect(bg, isNot(equals(FrozenPalette.action)));

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );




  });
}
