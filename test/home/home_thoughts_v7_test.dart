import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/features/feature_registry.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/v7/home_thoughts_v7.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AllUnlocked extends UnlockedFeaturesNotifier {
  @override
  Set<AscentFeature> build() => AscentFeature.values.toSet();
}

Thought _t(
  int id,
  String text, {
  String category = 'general',
  int minsAgo = 0,
}) => Thought(
  id: id,
  content: text,
  mood: 'thought',
  category: category,
  colorHex: '#2F6F6A',
  isPinned: false,
  isArchived: false,
  isCompleted: false,
  createdAt: DateTime.now().subtract(Duration(minutes: minsAgo)),
);

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<Thought> thoughts, {
    bool dark = false,
    double scale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thoughtLinkedTasksProvider.overrideWith(
            (ref, ids) => Stream.value(const <Task>[]),
          ),
          thoughtLinkedRemindersProvider.overrideWith(
            (ref, ids) => Stream.value(const <(int, Reminder)>[]),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          unlockedFeaturesProvider.overrideWith(_AllUnlocked.new),
          recentThoughtsStreamProvider.overrideWith(
            (ref) => Stream.value(thoughts),
          ),
          todayThoughtsCountStreamProvider.overrideWith(
            (ref) => Stream.value(thoughts.length),
          ),
        ],
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 1600),
              textScaler: TextScaler.linear(scale),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(child: HomeThoughtsSection()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('your thoughts on the right, replies from real links', (
    tester,
  ) async {
    await pump(tester, [
      _t(1, 'A slow Sunday', category: 'ideas', minsAgo: 5),
      _t(2, 'Just a note'),
    ]);
    expect(find.text('Thoughts'), findsOneWidget);
    expect(find.text('2 today'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_thought_1')), findsOneWidget);
    expect(
      find.textContaining('Kept in Ideas', findRichText: true),
      findsOneWidget,
    );
    // A plain note gets no made-up reply.
    expect(find.textContaining('Just a note'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_mind_field')), findsOneWidget);
  });

  testWidgets('empty explains what the section is for', (tester) async {
    await pump(tester, const [], dark: true);
    expect(find.byKey(const ValueKey('home_mind_empty')), findsOneWidget);
  });

  testWidgets('no overflow at 320 px and text scale 2', (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, [
      for (var i = 0; i < 100; i++)
        _t(i + 1, '- [x] milk\n- [ ] eggs number $i\n- [ ] bread', minsAgo: i),
    ], scale: 2);
    expect(tester.takeException(), isNull);
  });
}
