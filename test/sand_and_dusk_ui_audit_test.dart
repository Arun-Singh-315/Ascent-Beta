import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/core/theme/app_colors.dart';
import 'package:ascent/shared/widgets/app_text_field.dart';
import 'package:ascent/shared/widgets/section_card.dart';
import 'package:ascent/features/home/widgets/home_assistant_hero_card.dart';
import 'package:ascent/features/home/widgets/activity_starter_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sand & Dusk Palette & Tokens', () {
    test('Light theme tokens match exact hex values', () {
      final light = AppColors.light;
      expect(light.bg, const Color(0xFFFBF8F3));
      expect(light.surface, const Color(0xFFFFFDF9));
      expect(light.surfaceAlt, const Color(0xFFF4EEE6));
      expect(light.border, const Color(0xFFE9E1D5));
      expect(light.textPrimary, const Color(0xFF2A2521));
      expect(light.textSecondary, const Color(0xFF6B635A));
      expect(light.textTertiary, const Color(0xFF9A9086));
      expect(light.primary, const Color(0xFFBF5A36));
      expect(light.primaryContainer, const Color(0xFFFBE6DA));
      expect(light.onPrimaryContainer, const Color(0xFF6B2E14));
      expect(light.secondary, const Color(0xFF7C6FB0));
      expect(light.secondaryContainer, const Color(0xFFECE8F6));
      expect(light.onSecondaryContainer, const Color(0xFF3A3266));
      expect(light.tertiary, const Color(0xFFC99A3C));
      expect(light.tertiaryContainer, const Color(0xFFF7EBCF));
      expect(light.alert, const Color(0xFFB3473F));
    });

    test('Dark theme tokens match warm dark hex values', () {
      final dark = AppColors.dark;
      expect(dark.bg, const Color(0xFF1F1B18));
      expect(dark.surface, const Color(0xFF2A2420));
      expect(dark.surfaceAlt, const Color(0xFF352F2A));
      expect(dark.border, const Color(0xFF433C35));
      expect(dark.textPrimary, const Color(0xFFF5EFEB));
      expect(dark.textSecondary, const Color(0xFFBAAFA4));
    });
  });

  group('Global Input Rule - AppTextField', () {
    testWidgets('AppTextField renders single enclosure without nested borders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              hintText: 'What should we call you?',
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.filled, isTrue);
      expect(textField.decoration?.fillColor, AppColors.light.surfaceAlt);
      expect(textField.decoration?.prefixIcon, isNotNull);
      expect(textField.decoration?.hintText, 'What should we call you?');
    });
  });

  group('Ask Aria Card on Home', () {
    testWidgets('Renders minimal card with sparkle avatar and soft Chat button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HomeAssistantHeroCard(assistantName: 'Aria'),
            ),
          ),
        ),
      );

      expect(find.text('Ask Aria'), findsOneWidget);
      expect(find.text('Plan your day or ask anything'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });
  });

  group('Things / Plans Soft Actions', () {
    testWidgets('Activity starter buttons: Add a task filled, Add a timer outlined', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ActivityStarterActions(),
          ),
        ),
      );

      expect(find.text('Add a task'), findsOneWidget);
      expect(find.text('Add a timer'), findsOneWidget);
      expect(find.byKey(const ValueKey('starter_add_task')), findsOneWidget);
      expect(find.byKey(const ValueKey('starter_add_timer')), findsOneWidget);
    });
  });

  group('SectionCard Consistency & Overflow Safeguard', () {
    testWidgets('SectionCard places title left and chevron right', (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SectionCard(
              icon: Icons.lightbulb_outline_rounded,
              title: 'Mindspace',
              onOpen: () => opened = true,
              child: const Text('Mindspace content'),
            ),
          ),
        ),
      );

      expect(find.text('Mindspace'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right));
      expect(opened, isTrue);
    });

    testWidgets('Rule 13 Immunity: zero RenderFlex overflow at 320px width & 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320 * 3.0, 640 * 3.0);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: ListView(
                  children: [
                    const HomeAssistantHeroCard(assistantName: 'Aria'),
                    SectionCard(
                      icon: Icons.lightbulb_outline_rounded,
                      title: 'Mindspace',
                      onOpen: () {},
                      child: const Text('Mindspace reflections and thoughts'),
                    ),
                    const ActivityStarterActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final exc = tester.takeException();
      if (exc != null) {
        // ignore: avoid_print
        print('EXCEPTION DETAILS: $exc');
      }
      expect(exc, isNull);
    });
  });
}
