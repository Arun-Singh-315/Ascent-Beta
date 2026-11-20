import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/features/home/widgets/learning_hub_card.dart';
import 'package:ascent/features/home/widgets/quick_modules_nav_hub.dart';
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

  group('Home Cards Dark vs Day Theme Border Integrity Tests', () {


    testWidgets(
      'In Frozen Sky (Nordic) mode: cards remain styled with frozen palette',
      (tester) async {
        final nordicDark = AscentTheme.dark(preset: DayThemePreset.nordicSky);
        final homeNordic = HomeTheme.from(nordicDark);
        final g = homeNordic.extension<AscentGlass>()!;
        expect(g.frozen, isTrue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              recentThoughtsStreamProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              todayActivitiesProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              timeTrackingProvider.overrideWith(
                () => _FakeTimeTrackingNotifier(),
              ),
            ],
            child: MaterialApp(
              theme: nordicDark,
              home: Theme(
                data: homeNordic,
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: Column(
                      children: [
                        ActivityHubCard(),
                        LearningHubCard(),
                        QuickModulesNavHub(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Cards should render properly in frozen mode
        expect(
          find.byKey(const ValueKey('home_activity_card')),
          findsOneWidget,
        );
        expect(find.byType(LearningHubCard), findsOneWidget);
        expect(find.byType(QuickModulesNavHub), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}
