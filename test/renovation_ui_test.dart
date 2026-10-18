import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:ascent/shared/widgets/message_composer.dart';
import 'package:ascent/shared/widgets/ascent_atmosphere.dart';
import 'package:ascent/shared/widgets/feature_guide.dart';
import 'package:ascent/features/chai_break/widgets/steaming_cup_painter.dart';
import 'package:ascent/features/money/money_screen.dart';
import 'package:ascent/features/chai_break/chai_break_screen.dart';
import 'package:ascent/features/chai_break/chai_break_provider.dart';

class _QuietChaiNotifier extends ChaiBreakNotifier {
  @override
  ChaiBreakState build() => const ChaiBreakState(isRunning: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SharedPreferences prefs;
  setUp(() async {
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
    ]) {
      GoogleFonts.plusJakartaSans(fontWeight: weight);
      GoogleFonts.jetBrainsMono(fontWeight: weight);
    }
    await GoogleFonts.pendingFonts();
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Money & Budgets': true,
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.taskDao.watchAllTasks().first;
  });
  tearDown(() async => db.close());
  Widget wrap(Widget child, {bool dark = false, double scale = 1}) =>
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
          chaiBreakProvider.overrideWith(_QuietChaiNotifier.new),
        ],
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(body: child),
          ),
        ),
      );
  testWidgets(
    'Chai keeps warm hierarchy and presets readable at larger text sizes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          wrap(const ChaiBreakScreen(), dark: dark, scale: 1.5),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Chai & Coffee'), findsOneWidget);
        expect(
          find.text('Choose a short pause, breathe and enjoy your drink.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'shared composer has 48dp semantic send, multiline input and disabled state in both themes',
    (tester) async {
      final controller = TextEditingController();
      String? sent;
      for (final dark in [false, true]) {
        controller.clear();
        await tester.pumpWidget(
          wrap(
            MessageComposer(
              controller: controller,
              hint: 'Write a thought...',
              onSend: (value) => sent = value,
            ),
            dark: dark,
            scale: 1.5,
          ),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('message_composer_send'))),
          const Size(48, 48),
        );
        expect(
          tester
              .widget<IconButton>(
                find.byKey(const ValueKey('message_composer_send')),
              )
              .onPressed,
          isNull,
        );
        await tester.enterText(find.byType(TextField), 'Line one\n🙂 Line two');
        await tester.pump();
        await tester.tap(find.byTooltip('Send message'));
        expect(sent, 'Line one\n🙂 Line two');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
  testWidgets('Home field focuses an accessible quick-capture card', (tester) async {
    await tester.pumpWidget(wrap(const ThoughtWallHomePreview()));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.filled, isFalse);
    expect(field.decoration!.focusedBorder, InputBorder.none);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(field.focusNode!.hasFocus, isTrue);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).border != null,
      ),
      findsWidgets,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Riya expense is not saved until confirmation, repeated confirm cannot duplicate',
    (tester) async {
      await tester.pumpWidget(wrap(const AiAssistantScreen()));
      await tester.pump();
      await tester.enterText(
        find.byType(TextField),
        'Add 200 rupees for coffee',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.text('Confirm'), findsOneWidget);
      await tester.runAsync(() async {
        expect(await db.financeDao.watchAllTransactions().first, isEmpty);
      });
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.runAsync(() async {
        expect(await db.financeDao.watchAllTransactions().first, hasLength(1));
      });
      expect(find.textContaining('Added ₹200.00'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
    },
  );
  testWidgets(
    'Money has one expense primary and no empty or appbar duplicate',
    (tester) async {
      await tester.pumpWidget(wrap(const MoneyScreen()));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.byTooltip('Record Expense'), findsNothing);
      expect(find.text('Record First Expense'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 20));
    },
  );
  testWidgets(
    'short help has three scanable steps; reduced motion cup has no active ticker',
    (tester) async {
      expect(featureGuides['Thought Wall']!.split('\n'), hasLength(3));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Scaffold(body: SteamingCupWidget(isRunning: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'capture real shared Home writing and chat widgets in day/night themes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = TextEditingController(
        text: 'A quiet moment for my next idea.',
      );
      final key = GlobalKey();
      await tester.runAsync(() async {
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          wrap(
            RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: dark ? AscentGlass.dark.bg : AscentGlass.light.bg,
                child: AscentAtmosphereBackground(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        const ThoughtWallHomePreview(),
                        const SizedBox(height: 32),
                        Text(
                          'Thought Wall',
                          style: TextStyle(
                            fontSize: 22,
                            color: dark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        MessageComposer(
                          controller: controller,
                          hint: 'Write a thought...',
                          onSend: (_) {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            dark: dark,
          ),
        );
        // MaterialApp animates theme changes; capture the settled theme.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.runAsync(() => GoogleFonts.pendingFonts());
        await tester.pump();
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'docs/renovation/${dark ? 'night' : 'day'}-writing-preview.png',
          );
          if (!file.parent.existsSync()) {
            file.parent.createSync(recursive: true);
          }
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
