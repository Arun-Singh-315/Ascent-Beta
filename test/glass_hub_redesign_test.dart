import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/thought_wall/thought_wall_appearance_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayActivityItem row(int id, String type) => TodayActivityItem(
  id: 'task_$id',
  title: '$type activity $id',
  sourceType: type,
  categoryTag: type == 'medicine' ? 'Medicine' : 'Task',
  status: TodayActivityStatus.notStarted,
  elapsedSecondsToday: 0,
  kind: type == 'timer' ? ActivityKind.duration : ActivityKind.todo,
  plannedDate: DateTime.now().add(Duration(minutes: id)),
);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    if (Platform.environment['ASCENT_REDESIGN_CAPTURE'] == '1') {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester t, String name) async {
    if (Platform.environment['ASCENT_REDESIGN_CAPTURE'] != '1') return;
    await t.runAsync(() async {
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('redesign_capture')),
      );
      final picture = await boundary.toImage();
      final data = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/ascent-redesign-$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      picture.dispose();
    });
  }


  testWidgets('wall settings no longer offer ineffective card colours', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const Scaffold(body: ThoughtWallAppearanceSheet()),
        ),
      ),
    );
    expect(find.text('Card colour'), findsNothing);
    expect(find.text('Sage'), findsNothing);
    expect(find.text('Spacing'), findsOneWidget);
    expect(find.text('Bubble'), findsOneWidget);
  });
}
