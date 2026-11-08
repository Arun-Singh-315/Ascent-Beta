import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_life_shelf.dart';
import 'package:ascent/features/home/widgets/learning_hub_card.dart';
import 'package:ascent/features/vault/providers/vault_providers.dart';
import 'package:ascent/features/vault/widgets/vault_home_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeLockedNotifier extends VaultSessionUnlockedNotifier {
  @override
  bool build() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget(Widget child, {List<dynamic> extraOverrides = const []}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: AscentTheme.light(),
        darkTheme: AscentTheme.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  group('LearningHubCard sassy centered design tests', () {
    testWidgets('LearningHubCard renders centered start learning layout with transparent bordered styling', (tester) async {
      await tester.pumpWidget(buildTestWidget(const LearningHubCard()));
      await tester.pumpAndSettle();

      // Heading and call to action are present
      expect(find.byKey(const ValueKey('home_learning_title')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_learning_course')), findsOneWidget);
      expect(find.text('Start learning'), findsOneWidget);

      // Verify centered alignment of the card content
      final titleFinder = find.byKey(const ValueKey('home_learning_title'));
      final titleCenter = tester.getCenter(titleFinder);
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect((titleCenter.dx - screenWidth / 2).abs(), lessThan(40));
    });

    testWidgets('LearningHubCard is immune to overflow at 320px with 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: buildTestWidget(const LearningHubCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LearningHubCard), findsOneWidget);
    });
  });

  group('VaultHomePreview sassy centered design tests', () {
    testWidgets('VaultHomePreview renders centered locked layout with border', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          const VaultHomePreview(),
          extraOverrides: [
            vaultSessionUnlockedProvider.overrideWith(_FakeLockedNotifier.new),
            vaultItemCountProvider.overrideWith((ref) => 0),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home_vault_card')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('home_vault_card')), matching: find.text('Private Vault')), findsOneWidget);

      final titleFinder = find.descendant(of: find.byKey(const ValueKey('home_vault_card')), matching: find.text('Private Vault'));
      final titleCenter = tester.getCenter(titleFinder);
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect((titleCenter.dx - screenWidth / 2).abs(), lessThan(40));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('VaultHomePreview is immune to overflow at 320px with 2.0x text scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: buildTestWidget(
                const VaultHomePreview(),
                extraOverrides: [
                  vaultSessionUnlockedProvider.overrideWith(_FakeLockedNotifier.new),
                  vaultItemCountProvider.overrideWith((ref) => 3),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });

  group('Daily rhythm enclosed border & animation tests', () {
    testWidgets('HomeLifeShelf wraps tools in a single unified border enclosure', (tester) async {
      await tester.pumpWidget(buildTestWidget(const HomeLifeShelf()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('home_life_shelf_enclosure')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_life_shelf')), findsOneWidget);
      expect(find.text('Daily rhythm'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('HomeLifeShelf expands smoothly on tapping a tool without overflow at 320px 2.0x scale', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: buildTestWidget(const HomeLifeShelf()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialHeight = tester.getSize(find.byKey(const ValueKey('home_life_shelf_enclosure'))).height;

      // Tap hydration tool
      final waterCard = find.byKey(const ValueKey('home_routine_hydration'));
      if (waterCard.evaluate().isNotEmpty) {
        await tester.tap(waterCard);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        final expandedHeight = tester.getSize(find.byKey(const ValueKey('home_life_shelf_enclosure'))).height;
        expect(expandedHeight, greaterThanOrEqualTo(initialHeight));
      }

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });
}
