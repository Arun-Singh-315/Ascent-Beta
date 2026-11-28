import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/features/feature_registry.dart';
import 'package:ascent/core/promises/promise_providers.dart';
import 'package:ascent/core/promises/promise_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/v7/home_life_v7.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AllUnlocked extends UnlockedFeaturesNotifier {
  @override
  Set<AscentFeature> build() => AscentFeature.values.toSet();
}

class _Streak extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
    todaySeconds: 2700,
    yesterdaySeconds: 0,
    priorStreakDays: 0,
    historicalLongestStreak: 0,
    historicalShortestStreak: 0,
    now: DateTime(2026, 11, 28, 14),
  );
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    int waterMl = 1800,
    bool dark = false,
    double scale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          unlockedFeaturesProvider.overrideWith(_AllUnlocked.new),
          studyStreakProvider.overrideWith(_Streak.new),
          todayWaterMlStreamProvider.overrideWith(
            (ref) => Stream.value(waterMl),
          ),
          dailyWaterGoalStreamProvider.overrideWith(
            (ref) => Stream.value(2500),
          ),
          todayWaterLogsStreamProvider.overrideWith(
            (ref) => Stream.value([
              WaterLog(
                id: 1,
                amountMl: 250,
                timestamp: DateTime(now.year, now.month, now.day, 9),
                date: DateTime(now.year, now.month, now.day),
              ),
            ]),
          ),
          todayMedicineLogsStreamProvider.overrideWith(
            (ref) => Stream.value(const <MedicineLog>[]),
          ),
          activeMedicinesStreamProvider.overrideWith(
            (ref) => Stream.value(const <Medicine>[]),
          ),
          homeLifeSessionsProvider.overrideWith(
            (ref) => Stream.value(const <TimeSession>[]),
          ),
          todaySpendingStreamProvider.overrideWith((ref) => Stream.value(350)),
          currentMonthSpendingStreamProvider.overrideWith(
            (ref) => Stream.value(4200),
          ),
          overallBudgetStreamProvider.overrideWith((ref) => Stream.value(null)),
          recentTransactionsStreamProvider.overrideWith(
            (ref) => Stream.value(const <FinanceTransaction>[]),
          ),
          homePromisesProvider.overrideWithValue(
            const AsyncValue<List<PromiseView>>.data([]),
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
              body: SingleChildScrollView(child: HomeLifeSection()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('one row per feature with today’s value in its colour', (
    tester,
  ) async {
    await pump(tester);
    for (final id in ['water', 'medicine', 'focus', 'money', 'promise']) {
      expect(find.byKey(ValueKey('home_life_$id')), findsOneWidget, reason: id);
    }
    expect(find.text('Life'), findsOneWidget);
    // Water starts open with its log action.
    expect(find.byKey(const ValueKey('home_bento_water_add')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one row open at a time', (tester) async {
    await pump(tester, dark: true);
    await tester.tap(find.text('Focus'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('home_bento_focus_start')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home_bento_water_add')), findsNothing);
    await tester.tap(find.text('Focus'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('home_bento_focus_start')), findsNothing);
  });

  testWidgets('empty values show a dash, never 0', (tester) async {
    await pump(tester, waterMl: 0);
    final texts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .toList();
    expect(texts, contains('–/2.5 L'));
    expect(texts.where((t) => t.startsWith('0/') || t.startsWith('0 ')), isEmpty);
  });

  testWidgets('no promise yet invites one', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Promise'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('promise_make')), findsOneWidget);
  });

  testWidgets('no overflow at 320 px and text scale 2', (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, scale: 2);
    expect(tester.takeException(), isNull);
  });
}
