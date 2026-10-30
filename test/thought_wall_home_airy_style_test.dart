import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestApp({
    required Widget child,
    List<Thought> thoughts = const [],
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recentThoughtsStreamProvider.overrideWith((ref) => Stream.value(thoughts)),
      ],
      child: MaterialApp(
        theme: AscentTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: child,
          ),
        ),
      ),
    );
  }

  group('ThoughtWallHomePreview Airy Glass & Empty State Tests', () {
    testWidgets('When thoughts are empty, composer appears as a single sleek glass input placeholder without nested card container', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const ThoughtWallHomePreview(showComposer: true),
          thoughts: const [],
        ),
      );
      await tester.pumpAndSettle();

      // Renders input field
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Capture a thought…'), findsOneWidget);

      // Single enclosure key present
      expect(find.byKey(const ValueKey('home_mind_space_card')), findsOneWidget);

      // No thought items rendered
      expect(find.byKey(const ValueKey('home_thought_1')), findsNothing);
    });

    testWidgets('When thoughts are present, thoughts appear with airy glass bubble styling', (tester) async {
      final sampleThought = Thought(
        id: 1,
        content: 'This is a peaceful morning reflection',
        category: 'mindfulness',
        mood: 'calm',
        colorHex: '#0284C7',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isPinned: false,
        isArchived: false,
        isCompleted: false,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const ThoughtWallHomePreview(showComposer: true),
          thoughts: [sampleThought],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This is a peaceful morning reflection'), findsOneWidget);
      expect(find.byKey(const ValueKey('home_thought_1')), findsOneWidget);
    });

    testWidgets('Renders overflow-free at 320px width and 2.0x text scale', (tester) async {
      final sampleThought = Thought(
        id: 1,
        content: 'Long thought reflection to test wrap and layout scaling bounds',
        category: 'mindfulness',
        mood: 'calm',
        colorHex: '#0284C7',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isPinned: true,
        isArchived: false,
        isCompleted: false,
      );

      tester.view.physicalSize = const Size(320 * 2, 700 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2.0),
          ),
          child: buildTestApp(
            child: const ThoughtWallHomePreview(showComposer: true),
            thoughts: [sampleThought],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
