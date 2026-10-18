import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/shared/widgets/music_companion_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  const channel = MethodChannel('ascent/music');
  late Map<String, dynamic> status;
  late List<MethodCall> calls;

  setUp(() {
    status = {'access': false};
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'status') return status;
          return true;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AscentTheme.light(),
        home: const Scaffold(
          body: SingleChildScrollView(child: MusicCompanionCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('access is explained before opening system settings', (
    tester,
  ) async {
    await show(tester);
    expect(calls.where((c) => c.method == 'settings'), isEmpty);
    await tester.tap(find.text('Connect music'));
    await tester.pumpAndSettle();
    expect(find.textContaining('broad notification access'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.method == 'settings'), hasLength(1));
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('shows real metadata and sends controls to its source', (
    tester,
  ) async {
    status = {
      'access': true,
      'title': 'Quiet evening',
      'artist': 'Artist',
      'source': 'YouTube Music',
      'package': 'music.test',
      'playing': true,
      'toggle': true,
      'next': false,
    };
    await show(tester);
    expect(find.text('Quiet evening'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause music'));
    await tester.pumpAndSettle();
    expect(calls.singleWhere((c) => c.method == 'control').arguments, {
      'package': 'music.test',
      'action': 'toggle',
    });
    final next = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Next track',
      ),
    );
    expect(next.onPressed, isNull);
    status = {'access': false};
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Quiet evening'), findsNothing);
    expect(find.text('Connect music'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('unsupported platforms do not access native channel', (
    tester,
  ) async {
    await show(tester);
    expect(find.text('Music companion'), findsNothing);
    expect(calls, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  testWidgets('long titles fit narrow screens with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    status = {
      'access': true,
      'title':
          'A very long lecture title about building better habits and learning',
      'source': 'YouTube Music',
      'playing': true,
      'toggle': true,
    };
    await tester.pumpWidget(
      MaterialApp(
        theme: AscentTheme.dark(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const SingleChildScrollView(child: MusicCompanionCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
