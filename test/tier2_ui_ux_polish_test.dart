import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/hydration/hydration_screen.dart';
import 'package:ascent/app/theme/shared_control_tokens.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => db.close());

  group('Tier 2: Hydration Honest Numbers & Emoji Purge', () {
    testWidgets('shows First sip and invites action instead of raw 0% and 0 mL demotivation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayWaterLogsStreamProvider.overrideWith((ref) => Stream.value(<WaterLog>[])),
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(0)),
            dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2500)),
            past7DaysHydrationStreamProvider.overrideWith((ref) => Stream.value(<DailyHydrationRecord>[])),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const HydrationScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Ring text shows "First sip" at cold start
      expect(find.text('First sip'), findsOneWidget);

      // Prompt encourages first sip
      expect(find.text('Record your first sip below'), findsOneWidget);

      // No emojis in the card
      expect(find.textContaining('🎉'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });

  group('Tier 2: Semantic Color Tokens Discipline', () {
    test('dueRed is centralized in SharedControlColors for destructive actions', () {
      expect(SharedControlColors.dueRed, isNotNull);
      expect(SharedControlColors.dueRed, const Color(0xFFD92D20));
    });
  });
}
