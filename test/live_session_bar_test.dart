import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/shared/widgets/live_session_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

final _session = TimeSession(
  id: 1,
  label: 'Pitch deck',
  activityType: 'study',
  categoryId: 1,
  linkedTaskId: null,
  learningCourseId: null,
  learningLectureId: null,
  startedAt: DateTime(2026, 11, 22, 9),
  endedAt: null,
  pausedIntervals: '[]',
  status: 'running',
  durationSeconds: 0,
  activityRefType: 'task',
  lastHeartbeatAt: null,
  createdAt: DateTime(2026, 11, 22, 9),
);

class _FakeTimer extends TimeTrackingNotifier {
  _FakeTimer(this.initial);
  final TimeTrackingState initial;
  final calls = <String>[];

  @override
  TimeTrackingState build() => initial;

  @override
  Future<void> pauseSession() async {
    calls.add('pause');
    state = TimeTrackingState(
      activeSession: state.activeSession,
      elapsedSeconds: state.elapsedSeconds,
      isPaused: true,
    );
  }

  @override
  Future<void> resumeSession() async {
    calls.add('resume');
  }

  @override
  Future<bool> completeSession() async {
    calls.add('complete');
    state = const TimeTrackingState();
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<_FakeTimer> pump(
    WidgetTester tester,
    TimeTrackingState state, {
    double scale = 1,
  }) async {
    final fake = _FakeTimer(state);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [timeTrackingProvider.overrideWith(() => fake)],
        child: MaterialApp(
          theme: AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SizedBox.expand(),
            bottomNavigationBar: LiveSessionBar(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  final running = TimeTrackingState(
    activeSession: _session,
    elapsedSeconds: 754,
    isRunning: true,
  );

  testWidgets('nothing shows without a session', (tester) async {
    await pump(tester, const TimeTrackingState());
    expect(find.byKey(const ValueKey('live_session_bar')), findsNothing);
  });

  testWidgets('a running session shows its label, time and state', (
    tester,
  ) async {
    await pump(tester, running);
    expect(find.byKey(const ValueKey('live_session_bar')), findsOneWidget);
    expect(find.text('Pitch deck'), findsOneWidget);
    expect(find.text('12:34 · Running'), findsOneWidget);
  });

  testWidgets('pause works from the bar', (tester) async {
    final fake = await pump(tester, running);
    await tester.tap(find.byKey(const ValueKey('live_session_toggle')));
    await tester.pumpAndSettle();
    expect(fake.calls, ['pause']);
    expect(find.textContaining('Paused'), findsOneWidget);
  });

  testWidgets('finish asks first, then saves', (tester) async {
    final fake = await pump(tester, running);
    await tester.tap(find.byKey(const ValueKey('live_session_done')));
    await tester.pumpAndSettle();
    expect(find.text('Finish this session?'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['complete']);
    expect(find.byKey(const ValueKey('live_session_bar')), findsNothing);
  });

  testWidgets('fits 320 px at 2x text', (tester) async {
    await pump(tester, running, scale: 2);
    expect(tester.takeException(), isNull);
  });
}
