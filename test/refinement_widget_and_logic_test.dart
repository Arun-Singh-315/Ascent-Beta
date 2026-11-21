import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/shared/widgets/app_chip.dart';
import 'package:ascent/shared/widgets/capped_chip_wrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'weather_city': 'Bengaluru, India',
      'ascent_theme_mode': 'dark',
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Phase 3: Overflow Detection & ID-based Expansion Tests', () {


  });

  group('Phase 4: CappedChipWrap & Swipe Delete Tests', () {
    testWidgets(
      'CappedChipWrap caps at 2 rows and shows "+N more" chip, expanding inline on tap',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: Scaffold(
              body: SizedBox(
                width: 300, // Narrow container forcing wrap beyond 2 rows
                child: CappedChipWrap(
                  maxRows: 2,
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    AppChip(label: 'Alpha Chip One'),
                    AppChip(label: 'Beta Chip Two'),
                    AppChip(label: 'Gamma Chip Three'),
                    AppChip(label: 'Delta Chip Four'),
                    AppChip(label: 'Epsilon Chip Five'),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Should show "+N more" chip
        final moreFinder = find.textContaining('more');
        expect(moreFinder, findsOneWidget);

        // Tap "+N more" to expand
        await tester.tap(moreFinder);
        await tester.pumpAndSettle();

        // All 5 chips and "Show less" are visible
        expect(find.text('Alpha Chip One'), findsOneWidget);
        expect(find.text('Epsilon Chip Five'), findsOneWidget);
        expect(find.text('Show less'), findsOneWidget);

        // Tap "Show less" to collapse back
        await tester.tap(find.text('Show less'));
        await tester.pumpAndSettle();

        expect(find.textContaining('more'), findsOneWidget);
      },
    );

  });

  group('Phase 5: 320px Width & 2.0x Text Scale Immunity', () {
  });
}
