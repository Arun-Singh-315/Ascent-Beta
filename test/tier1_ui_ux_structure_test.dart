import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/history/history_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/history/history_screen.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/shared/widgets/ascent_segmented_control.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockTimeNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

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

  group('Tier 1: History Screen Day Rollups & Classification', () {
    testWidgets('groups items into day rollup cards with count badges', (tester) async {
      final now = DateTime.now();
      final entries = [
        HistoryEvent(
          id: '1',
          module: 'tasks',
          entityId: '1',
          action: 'completed',
          title: 'Morning Yoga',
          detail: 'Completed routine.',
          occurredAt: now,
          isPrivate: false,
          imported: false,
        ),
        HistoryEvent(
          id: '2',
          module: 'focus',
          entityId: '2',
          action: 'completed',
          title: 'Deep Work Session',
          detail: '45 minutes focus.',
          occurredAt: now,
          isPrivate: false,
          imported: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            timeTrackingProvider.overrideWith(_MockTimeNotifier.new),
            sharedPreferencesProvider.overrideWithValue(prefs),
            allPromisesStreamProvider.overrideWith((ref) => Stream.value([])),
            historyEventsProvider.overrideWith((ref) => Stream.value(entries)),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const HistoryScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Rollup header "Today" and "2 events"
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('2 events'), findsOneWidget);

      // Event titles exist within the ledger
      expect(find.text('Morning Yoga'), findsOneWidget);
      expect(find.text('Deep Work Session'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Tier 1: AscentSegmentedControl Large Text Immunity', () {
    testWidgets('vertical large-text layout accommodates long labels at 320px / 2.0x scale', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 600),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AscentSegmentedControl<String>(
                  segments: const [
                    AscentSegment(value: 'all', label: 'All Activities'),
                    AscentSegment(value: 'done', label: 'Finished Items'),
                    AscentSegment(value: 'other', label: 'Archived & Missed Events'),
                  ],
                  selected: 'all',
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Archived & Missed Events'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
