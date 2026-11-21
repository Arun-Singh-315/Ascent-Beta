import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/features/thought_wall/thought_wall_preferences.dart';
import 'package:ascent/features/thought_wall/thought_wall_appearance_sheet.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'support/returning_user_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({...returningUserGuidePrefs});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp(Widget child, {double width = 390, double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        thoughtDaoProvider.overrideWithValue(db.thoughtDao),
        sharedPreferencesProvider.overrideWithValue(prefs),
        userProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }


  group('Thought appearance settings', () {
    testWidgets('settings no longer expose Home thought card controls', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Thought Cards'), findsNothing);
      expect(find.text('Apply to Home'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('wall appearance stays scoped to the wall', (tester) async {
      await tester.pumpWidget(
        buildApp(const Scaffold(body: ThoughtWallAppearanceSheet())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Apply to Home'), findsNothing);
      await tester.tap(find.text('Comfortable'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ThoughtWallAppearanceSheet)),
      );
      expect(
        container.read(thoughtWallAppearanceProvider).density,
        ThoughtCardDensity.comfortable,
      );
      expect(find.text('Card colour'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Thought Wall Toggle and Selection Delete Option Outside', () {
  });

  group('Home Thought Preview Custom Tone and Font Typography', () {
  });
}
