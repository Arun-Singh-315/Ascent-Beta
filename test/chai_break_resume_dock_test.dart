import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/chai_break/widgets/chai_break_resume_dock.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/providers/settings_provider.dart';

class _FakeActiveTimeTrackingNotifier extends TimeTrackingNotifier {
  final TimeSession? session;
  _FakeActiveTimeTrackingNotifier([this.session]);

  @override
  TimeTrackingState build() {
    return TimeTrackingState(
      activeSession: session,
      elapsedSeconds: session != null ? 300 : 0,
      isPaused: true,
    );
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('Chai Break Resume Dock UI Tests', () {
    testWidgets('Renders single Go to Learning button when only lecture is active', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeActiveTimeTrackingNotifier(null)),
        ],
      );

      final learningNotifier = container.read(learningHubProvider.notifier);
      learningNotifier.startLearning();
      learningNotifier.seekBy(120);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              bottomNavigationBar: ChaiBreakResumeDock(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Go to Learning'), findsOneWidget);
      expect(find.text('Go to Todo'), findsNothing);
      // Ensure no live timer clock digits (e.g. "02:00") are cluttering the button
      expect(find.textContaining('02:00'), findsNothing);
    });

    testWidgets('Renders side-by-side buttons when both lecture and task timer are active', (tester) async {
      final dummySession = TimeSession(
        id: 1,
        categoryId: 1,
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        status: 'paused',
        label: 'Spring Boot Masterclass',
        activityType: 'study',
        activityRefType: 'task',
        durationSeconds: 300,
        pausedIntervals: '[]',
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeActiveTimeTrackingNotifier(dummySession)),
        ],
      );

      final learningNotifier = container.read(learningHubProvider.notifier);
      learningNotifier.startLearning();
      learningNotifier.seekBy(120);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              bottomNavigationBar: ChaiBreakResumeDock(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Go to Learning'), findsOneWidget);
      expect(find.text('Go to Todo'), findsOneWidget);
      expect(find.textContaining('Spring Boot Masterclass'), findsOneWidget);
    });

    testWidgets('Renders nothing (SizedBox.shrink) when neither is active', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeActiveTimeTrackingNotifier(null)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              bottomNavigationBar: ChaiBreakResumeDock(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Go to Learning'), findsNothing);
      expect(find.text('Go to Todo'), findsNothing);
    });
  });
}
