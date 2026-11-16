import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/thought_theme.dart';
import 'package:ascent/shared/widgets/section_card.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'weather_city': 'Bengaluru, India',
    });
    prefs = await SharedPreferences.getInstance();
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  final themes = <String, ThemeData>{
    'merlot_light': AscentTheme.light(preset: DayThemePreset.merlotLinen),
    'merlot_dark': AscentTheme.dark(preset: DayThemePreset.merlotLinen),
    'frost_light': AscentTheme.light(preset: DayThemePreset.nordicSky),
    'frost_dark': AscentTheme.dark(preset: DayThemePreset.nordicSky),
    'evergreen_light': AscentTheme.light(preset: DayThemePreset.classicClay),
    'evergreen_dark': AscentTheme.dark(preset: DayThemePreset.classicClay),
    'dusk_light': AscentTheme.light(preset: DayThemePreset.classicClay),
    'dusk_dark': AscentTheme.dark(preset: DayThemePreset.classicClay),
  };

  final widths = <String, double>{
    '320px': 320.0,
    '390px': 390.0,
  };

  final sampleThought = Thought(
    id: 1,
    content: 'A quiet space for thought. Clarity emerges when we embrace stillness.',
    mood: 'idea',
    category: 'mind',
    colorHex: '#2F6F6A',
    isPinned: false,
    isArchived: false,
    isCompleted: false,
    createdAt: DateTime(2026, 11, 15, 10, 30),
  );

  for (final themeEntry in themes.entries) {
    for (final widthEntry in widths.entries) {
      testWidgets('Golden: Home Header & SectionCard & Thought Hero - ${themeEntry.key} (${widthEntry.key})', (tester) async {
        final width = widthEntry.value;
        tester.view.physicalSize = Size(width * 2.0, 900 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final rootKey = GlobalKey();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: themeEntry.value,
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                backgroundColor: themeEntry.value.scaffoldBackgroundColor,
                body: RepaintBoundary(
                  key: rootKey,
                  child: SizedBox(
                    width: width,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        HomeHeader(
                          profile: null,
                          now: DateTime(2026, 11, 15, 9, 30),
                        ),
                        const SizedBox(height: 12),
                        SectionCard(
                          icon: Icons.bubble_chart_rounded,
                          title: 'Mindspace',
                          child: ThoughtCardBubble(
                            thought: sampleThought,
                            index: 0,
                            role: ThoughtCardRole.hero,
                          ),
                        ),
                        SectionCard(
                          icon: Icons.notes_rounded,
                          title: 'Older Thoughts',
                          child: Column(
                            children: [
                              ThoughtCardBubble(
                                thought: sampleThought.copyWith(id: 2, content: 'Standard reflection in quiet tone.'),
                                index: 1,
                                role: ThoughtCardRole.standard,
                              ),
                              const SizedBox(height: 8),
                              ThoughtCardBubble(
                                thought: sampleThought.copyWith(id: 3, content: 'Compact thought for quick glance.'),
                                index: 2,
                                role: ThoughtCardRole.compact,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byKey(rootKey),
          matchesGoldenFile('goldens/${themeEntry.key}_${widthEntry.key}.png'),
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
}
