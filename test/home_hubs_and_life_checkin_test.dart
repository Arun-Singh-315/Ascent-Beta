import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/splash/splash_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Splash Screen Tagline Requirement', () {
    testWidgets(
      'SplashScreen tagline promotes personal clarity and not job prep or local os',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const SplashScreen(),
            ),
          ),
        );

        expect(find.text('Personal Clarity, Focus & Rhythm'), findsOneWidget);
        expect(find.textContaining('Job Prep'), findsNothing);
        expect(find.textContaining('Operating System'), findsNothing);

        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );
  });

  group('Activity Hub (Things Hub) UI Refinements', () {

  });

  group('Modern Curved Popup Menu Theme', () {
  });
}
